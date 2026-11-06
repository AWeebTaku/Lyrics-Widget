#include "LyricsFetcher.h"

#include "LrcParser.h"
#include "RomanAlign.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrlQuery>
#include <utility>

namespace {
constexpr double kMinScore = 0.55;
constexpr double kSyncedBonus = 0.15;
constexpr qint64 kGapMs = 100;   // min spacing between requests to one host (burst guard)
constexpr qint64 kMemoMs = 10 * 60 * 1000;
// Verbose log (see: journalctl --user -u plasma-plasmashell): LYRICS_DEBUG=1, or `touch ~/.cache/lyric-widget/debug`
const bool kDebug = qEnvironmentVariableIsSet("LYRICS_DEBUG")
                    || QFile::exists(QDir::homePath() + QStringLiteral("/.cache/lyric-widget/debug"));

QString queryFor(const Candidate &c)
{
    return c.artist.isEmpty() ? c.title : c.artist + QLatin1Char(' ') + c.title;
}

LyricsResult fromLrclib(const QJsonObject &o)
{
    LyricsResult r;
    r.instrumental = o.value(QStringLiteral("instrumental")).toBool();
    r.synced = o.value(QStringLiteral("syncedLyrics")).toString();
    r.plain = o.value(QStringLiteral("plainLyrics")).toString();
    r.found = r.instrumental || !r.synced.isEmpty() || !r.plain.isEmpty();
    r.sourceId = QStringLiteral("lrclib:") + QString::number(o.value(QStringLiteral("id")).toInteger());
    return r;
}

bool looksSynced(const QString &s) { return Text::usableLrc(s); }
} // namespace

struct LyricsFetcher::Job {
    quint64 id = 0;
    Track track;
    QVector<Candidate> cands;
    LyricsResult lrc, ne, qq, kg, yt;
    LyricsResult lrcFallback, exactPlain; // exact-match hit held back: romaji-only copy of a CJK song
    bool lrcFailed = false, lrcDone = false, neDone = false, qqDone = false, kgDone = false, ytStarted = false, ytDone = false, published = false, finalSent = false;
};

LyricsFetcher::LyricsFetcher(QObject *parent) : QObject(parent) {}

quint64 LyricsFetcher::lookup(const Track &t)
{
    m_current = ++m_nextId; // first: aborted replies' handlers must already see themselves as stale
    qDeleteAll(m_parts);
    m_parts.clear();
    Track ta, tb;
    if (Text::splitTransition(t, ta, tb))
        return lookupTransition(t, ta, tb);
    // Stale replies are not aborted: aborting mid-flight stalled later requests on the shared
    // connections. They finish harmlessly (tiny responses) and get ignored by the job-id check.
    auto job = std::make_shared<Job>();
    job->id = m_current;
    job->track = t;
    job->cands = Text::candidates(t);
    if (job->cands.isEmpty()) {
        job->lrcDone = job->neDone = job->qqDone = job->kgDone = true;
        publish(job);
        return job->id;
    }
    start(job);
    return job->id;
}

void LyricsFetcher::start(const JobPtr &job)
{
    lrclib(job);
    netease(job);
    qq(job);
    kugou(job);
    // A provider that has not answered in 7 s (QQ often does) must not hold the answer up: the
    // others' lyrics, romanization and word timing are published without it.
    QTimer::singleShot(7000, this, [this, job] {
        if (job->finalSent)
            return;
        auto giveUp = [](bool &done, LyricsResult &r) { if (!done) { done = true; r.networkError = true; } };
        giveUp(job->lrcDone, job->lrc);
        giveUp(job->neDone, job->ne);
        giveUp(job->qqDone, job->qq);
        giveUp(job->kgDone, job->kg);
        publish(job);
    });
}

// A mix of two songs: look both up, then play the second one's lyrics after the first's. Where the second song
// starts is a guess (the mix ends with it), so the timing may need a nudge or an edit in the library.
quint64 LyricsFetcher::lookupTransition(const Track &t, const Track &a, const Track &b)
{
    struct State { LyricsResult r[2]; bool done[2] = {false, false}; };
    auto st = std::make_shared<State>();
    const quint64 id = m_current;
    const int total = t.durationSec;
    int i = 0;
    for (const Track &part : {a, b}) {
        auto *f = new LyricsFetcher(this);
        m_parts << f;
        connect(f, &LyricsFetcher::result, this, [this, st, i, id, total](quint64, const LyricsResult &r, bool final) {
            st->r[i] = r;
            st->done[i] = final;
            if (id != m_current || !st->done[0] || !st->done[1])
                return;
            const LyricsResult &x = st->r[0], &y = st->r[1];
            LyricsResult out = x.found && !y.found ? x : y.found && !x.found ? y : x;
            if (x.found && y.found) {
                out.sourceId = x.sourceId + QLatin1Char('+') + y.sourceId;
                out.plain = x.plain + QStringLiteral("\n\n") + y.plain;
                out.roman.clear();
                out.instrumental = false;
                out.srcDur = total;
                out.synced.clear();
                if (!x.synced.isEmpty() && !y.synced.isEmpty()) {
                    const auto lines = Lrc::parse(x.synced);
                    const qint64 end = lines.isEmpty() ? 0 : lines.last().timeMs + 2000;
                    // the mix ends with the second song, so line its end up with the mix's end
                    const qint64 at = std::max<qint64>(end, total > 0 && y.srcDur > 0 ? qint64((total - y.srcDur) * 1000) : end);
                    out.synced = x.synced + QLatin1Char('\n') + Lrc::mapStamps(y.synced, [at](qint64 ms) { return ms + at; });
                }
            }
            out.networkError = x.networkError || y.networkError;
            out.found = x.found || y.found;
            emit result(id, out, true);
        });
        f->lookup(part);
        ++i;
    }
    return id;
}

// Keeps the memo small: only the newest few downloads are worth remembering for a replay or a retry.
void LyricsFetcher::rememberDownload(const QUrl &url, const QByteArray &body)
{
    constexpr int kMaxMemo = 24;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    m_memo.insert(url, {now, body});
    if (m_memo.size() <= kMaxMemo)
        return;
    for (auto it = m_memo.begin(); it != m_memo.end();)
        it = now - it->first >= kMemoMs ? m_memo.erase(it) : std::next(it);
    while (m_memo.size() > kMaxMemo) { // still too many: drop the oldest
        auto oldest = m_memo.begin();
        for (auto it = m_memo.begin(); it != m_memo.end(); ++it)
            if (it->first < oldest->first)
                oldest = it;
        m_memo.erase(oldest);
    }
}

void LyricsFetcher::get(const JobPtr &job, const QUrl &url, Reply cb, int attempt)
{
    // Answered recently (retry, replay, same query from another phrasing): no request at all.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (const auto it = m_memo.constFind(url); it != m_memo.constEnd() && now - it->first < kMemoMs) {
        const QByteArray body = it->second;
        QTimer::singleShot(0, this, [this, job, cb, body] {
            if (job->id == m_current)
                cb(true, false, body);
        });
        return;
    }
    // Pace requests per host: providers throttle bursts (429/503, NetEase silent empties).
    qint64 &slot = nextSlot()[url.host()]; // shared with the look-ahead fetcher: one pace per host
    const qint64 wait = std::max<qint64>(0, slot - now);
    slot = now + wait + kGapMs;
    if (wait > 0) {
        QTimer::singleShot(wait, this, [this, job, url, cb, attempt] {
            if (job->id == m_current)
                send(job, url, cb, attempt);
        });
        return;
    }
    send(job, url, std::move(cb), attempt);
}

void LyricsFetcher::send(const JobPtr &job, const QUrl &url, Reply cb, int attempt)
{
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Mozilla/5.0 (X11; Linux x86_64) lyric-widget/0.3"));
    if (url.host().contains(QLatin1String("163.com")))
        req.setRawHeader("Referer", "https://music.163.com");
    else if (url.host().contains(QLatin1String("qq.com")))
        req.setRawHeader("Referer", "https://y.qq.com/"); // QQ answers erratically without it
    req.setTransferTimeout(5000); // a stalled provider must not hold up the final result
    QNetworkReply *reply = m_nam.get(req);
    if (kDebug)
        qWarning() << "GET" << job->id << attempt << url.toString(QUrl::RemoveQuery) << url.query().left(60);
    connect(reply, &QNetworkReply::finished, this, [this, reply, job, url, attempt, cb = std::move(cb)] {
        reply->deleteLater();
        const auto err = reply->error();
        const QByteArray body = reply->readAll();
        // Remember lyric downloads (not searches: a throttled provider's empty answer must not stick).
        const QString path = url.path();
        if (err == QNetworkReply::NoError && body.size() > 200
            && (path.contains(QLatin1String("lyric")) || path == QLatin1String("/api/get")))
            rememberDownload(url, body);
        if (job->id != m_current)
            return; // superseded by a newer track
        // LRCLIB answers 429/503 now and then for perfectly good queries: back off and retry.
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (kDebug)
            qWarning() << "  <-" << job->id << http << err << url.host();
        if (attempt < 2 && (http == 429 || http >= 500)) {
            QTimer::singleShot(attempt == 0 ? 500 : 1200, this, [this, job, url, cb, attempt] {
                if (job->id == m_current)
                    get(job, url, cb, attempt + 1);
            });
            return;
        }
        if (err != QNetworkReply::NoError && err != QNetworkReply::ContentNotFoundError && kDebug)
            qWarning() << "lyrics request failed:" << url.toString(QUrl::RemoveQuery) << reply->errorString();
        cb(err == QNetworkReply::NoError, err == QNetworkReply::ContentNotFoundError, body);
    });
}

// ---------------------------------------------------------- parallel search

// Runs the search for the first `maxCands` phrasings at once (latency = slowest, not the sum)
// and reports the best-scoring hit.
void LyricsFetcher::searchAll(const JobPtr &job, int maxCands, SearchUrl url, SearchParse parse,
                              SearchDone done)
{
    const int n = std::min<int>(job->cands.size(), maxCands);
    auto g = std::make_shared<Gather>();
    g->pending = n;
    for (int i = 0; i < n; ++i) {
        const Candidate c = job->cands.at(i);
        get(job, url(c), [g, c, parse, done](bool ok, bool, const QByteArray &body) {
            if (ok)
                parse(QJsonDocument::fromJson(body), c, *g);
            else
                g->failed = true;
            if (--g->pending == 0)
                done(*g);
        });
    }
}

// ------------------------------------------------------------------ LRCLIB

void LyricsFetcher::lrclib(const JobPtr &job)
{
    auto search = [this, job] {
        searchAll(
            job, 2, // parallel searches per provider: faster, but 3+ trips rate limits
            [](const Candidate &c) {
                // free-text "q" ranks far better than the strict track_name/artist_name fields
                QUrl u(QStringLiteral("https://lrclib.net/api/search"));
                QUrlQuery q;
                q.addQueryItem(QStringLiteral("q"), queryFor(c));
                u.setQuery(q);
                return u;
            },
            [job](const QJsonDocument &doc, const Candidate &c, Gather &g) {
                for (const auto &v : doc.array()) {
                    const QJsonObject o = v.toObject();
                    double s = Text::score(c, job->track.durationSec, o.value(QStringLiteral("trackName")).toString(),
                                           o.value(QStringLiteral("artistName")).toString(),
                                           o.value(QStringLiteral("duration")).toDouble(), job->track.album,
                                           o.value(QStringLiteral("albumName")).toString());
                    if (s < 0)
                        continue;
                    const QString synced = o.value(QStringLiteral("syncedLyrics")).toString();
                    if (job->track.skip.contains(QStringLiteral("lrclib:") + QString::number(o.value(QStringLiteral("id")).toInteger()))
                        || (job->track.onlySynced && synced.isEmpty()))
                        continue; // already shown, or not wanted
                    if (Text::langMismatch(synced.isEmpty() ? o.value(QStringLiteral("plainLyrics")).toString() : synced, job->track.lang))
                        continue; // another language's version of the same title
                    // the fullest plain text among the good matches: uploads often skip verses
                    const QString plain = o.value(QStringLiteral("plainLyrics")).toString();
                    if (s >= kMinScore && plain.size() > g.plain.size())
                        g.plain = plain;
                    if (!synced.isEmpty())
                        s += kSyncedBonus;
                    if (s > g.score) {
                        g.score = s;
                        g.obj = o;
                    }
                    if (!synced.isEmpty()) { // original script vs romaji-only copy
                        if (Text::isCjk(synced) && s > g.scriptScore) { g.scriptScore = s; g.script = o; }
                        if (!Text::hasNonLatin(synced) && s > g.altScore) { g.altScore = s; g.alt = o; }
                    }
                }
            },
            [this, job](const Gather &g) {
                if (kDebug)
                    qWarning() << "lrclib pick" << g.score << g.obj.value(QStringLiteral("trackName")).toString()
                               << g.obj.value(QStringLiteral("artistName")).toString()
                               << g.obj.value(QStringLiteral("duration")).toDouble();
                LyricsResult r;
                if (g.score >= kMinScore) {
                    r = fromLrclib(g.obj);
                    r.conf = g.score;
                    r.srcDur = g.obj.value(QStringLiteral("duration")).toDouble();
                }
                // Both an original-script and a romaji-only version exist: show the original, and
                // keep the human-made romaji as its romanization.
                if (g.scriptScore >= kMinScore && g.altScore >= kMinScore) {
                    r = fromLrclib(g.script);
                    r.conf = g.scriptScore;
                    r.srcDur = g.script.value(QStringLiteral("duration")).toDouble();
                    r.roman = g.alt.value(QStringLiteral("syncedLyrics")).toString();
                }
                if (r.found && Text::isCjk(r.synced) && job->lrcFallback.found && r.roman.isEmpty())
                    r.roman = job->lrcFallback.synced; // the exact-match romaji copy
                if (job->lrcFallback.found && (!r.found || !Text::hasNonLatin(job->track.title + job->track.artist)
                                               || !Text::hasNonLatin(r.synced)))
                    r = job->lrcFallback; // nothing better than the romaji copy
                if (job->exactPlain.found && r.synced.isEmpty())
                    r = job->exactPlain; // the exact hit had text but no timing, and neither did the search
                if (r.found && !r.synced.isEmpty() && g.plain.size() > r.plain.size() * 1.15)
                    r.plain = g.plain;
                r.networkError = !r.found && g.failed;
                finishLrclib(job, r);
            });
    };

    const Track &t = job->track;
    const Candidate &c = job->cands.first();
    if (t.album.isEmpty() || t.durationSec <= 0 || c.artist.isEmpty()) {
        search();
        return;
    }
    // Exact match first: one fast round trip when the player gives proper song metadata.
    QUrl url(QStringLiteral("https://lrclib.net/api/get"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("track_name"), c.title);
    q.addQueryItem(QStringLiteral("artist_name"), c.artist);
    q.addQueryItem(QStringLiteral("album_name"), t.album);
    q.addQueryItem(QStringLiteral("duration"), QString::number(t.durationSec));
    url.setQuery(q);
    get(job, url, [this, job, search](bool ok, bool notFound, const QByteArray &body) {
        if (ok) {
            LyricsResult r = fromLrclib(QJsonDocument::fromJson(body).object());
            r.conf = 2; // exact title + artist + album + duration
            r.srcDur = job->track.durationSec;
            if (r.found && (job->track.skip.contains(r.sourceId) || (job->track.onlySynced && r.synced.isEmpty())))
                r = LyricsResult(); // shown before / not wanted: the search finds the next one
            if (r.found && Text::langMismatch(r.synced.isEmpty() ? r.plain : r.synced, job->track.lang))
                r = LyricsResult(); // wrong language version: let the search find the right one
            if (r.found) {
                // CJK song whose exact hit is Latin-only: likely a user-made romaji copy. Keep it
                // as the fallback and let the search look for the real script version.
                if (Text::hasNonLatin(job->track.title + job->track.artist) && !r.synced.isEmpty()
                    && !Text::hasNonLatin(r.synced)) {
                    job->lrcFallback = r;
                    search();
                    return;
                }
                if (r.synced.isEmpty()) { // plain text only: the search may hold a synced copy
                    job->exactPlain = r;
                    search();
                    return;
                }
                finishLrclib(job, r);
                return;
            }
        } else if (!notFound) {
            // 5xx/429 after retries: the search below may still work
        }
        search();
    });
}

// ----------------------------------------------------------------- NetEase

void LyricsFetcher::netease(const JobPtr &job)
{
    searchAll(
        job, 2, // parallel searches per provider: faster, but 3+ trips rate limits
        [](const Candidate &c) {
            QUrl u(QStringLiteral("https://music.163.com/api/search/get"));
            QUrlQuery q;
            q.addQueryItem(QStringLiteral("s"), queryFor(c));
            q.addQueryItem(QStringLiteral("type"), QStringLiteral("1"));
            q.addQueryItem(QStringLiteral("limit"), QStringLiteral("8"));
            u.setQuery(q);
            return u;
        },
        [job](const QJsonDocument &doc, const Candidate &c, Gather &g) {
            const QJsonObject root = doc.object();
            if (kDebug)
                qWarning() << "netease search" << c.artist << c.title << "code" << root.value(QStringLiteral("code")).toInt(-1)
                           << "songs" << root.value(QStringLiteral("result")).toObject().value(QStringLiteral("songs")).toArray().size();
            if (root.value(QStringLiteral("code")).toInt(200) != 200) {
                // rate-limited with HTTP 200 + an error code: a failure, not "no such song"
                g.failed = true;
                return;
            }
            for (const auto &v : root.value(QStringLiteral("result")).toObject()
                                     .value(QStringLiteral("songs")).toArray()) {
                const QJsonObject o = v.toObject();
                QStringList artists;
                for (const auto &a : o.value(QStringLiteral("artists")).toArray())
                    artists << a.toObject().value(QStringLiteral("name")).toString();
                const double dur = o.value(QStringLiteral("duration")).toDouble() / 1000.0;
                const double s = Text::score(c, job->track.durationSec, o.value(QStringLiteral("name")).toString(),
                                             artists.join(QLatin1Char(' ')), dur, job->track.album,
                                             o.value(QStringLiteral("album")).toObject().value(QStringLiteral("name")).toString());
                if (kDebug)
                    qWarning() << "netease candidate" << o.value(QStringLiteral("name")).toString() << artists << dur
                               << "score" << s << "| wanted" << c.title << c.artist << job->track.durationSec
                               << "artist similarity" << Text::similarity(c.artist, artists.join(QLatin1Char(' ')))
                               << "romanized" << Romanizer::line(artists.join(QLatin1Char(' ')));
                if (job->track.skip.contains(QStringLiteral("netease:") + QString::number(o.value(QStringLiteral("id")).toInteger())))
                    continue;
                if (s > g.score) {
                    g.score = s;
                    g.dur = dur;
                    g.id = QString::number(o.value(QStringLiteral("id")).toInteger());
                    g.obj = QJsonObject{{QStringLiteral("n"), o.value(QStringLiteral("name")).toString() + QLatin1Char('/') + artists.join(QLatin1Char(','))}};
                }
            }
        },
        [this, job](const Gather &g) {
            if (kDebug)
                qWarning() << "netease pick" << g.score << g.obj.value(QStringLiteral("n")).toString();
            if (g.score >= kMinScore && !g.id.isEmpty()) {
                neteaseLyric(job, g.id.toLongLong(), g.score, g.dur);
            } else {
                LyricsResult r;
                r.networkError = g.failed;
                finishNetease(job, r);
            }
        });
}

void LyricsFetcher::neteaseLyric(const JobPtr &job, qint64 songId, double conf, double dur)
{
    QUrl url(QStringLiteral("https://music.163.com/api/song/lyric/v1"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("id"), QString::number(songId));
    // -1 on all = "send everything": original, translation, romanization
    for (const char *k : {"lv", "kv", "tv", "rv"})
        q.addQueryItem(QString::fromLatin1(k), QStringLiteral("-1"));
    url.setQuery(q);
    get(job, url, [this, job, conf, dur, songId](bool ok, bool, const QByteArray &body) {
        LyricsResult r;
        r.conf = conf;
        r.srcDur = dur;
        r.sourceId = QStringLiteral("netease:") + QString::number(songId);
        const QJsonObject o = QJsonDocument::fromJson(body).object();
        if (!ok || o.value(QStringLiteral("code")).toInt(200) != 200) {
            r.networkError = true;
            finishNetease(job, r);
            return;
        }
        const QString lrc = o.value(QStringLiteral("lrc")).toObject().value(QStringLiteral("lyric")).toString();
        if (!o.value(QStringLiteral("uncollected")).toBool() && !lrc.isEmpty()
            && !lrc.contains(QStringLiteral("暂无歌词")) && !lrc.contains(QStringLiteral("纯音乐"))) {
            (looksSynced(lrc) ? r.synced : r.plain) = lrc;
            r.roman = o.value(QStringLiteral("romalrc")).toObject().value(QStringLiteral("lyric")).toString();
            r.found = true;
        }
        finishNetease(job, r);
    });
}

// ---------------------------------------------------------------- QQ Music

// Word timing and romanization only: asks NetEase alone, for songs whose lyrics came from elsewhere
// (the Spotify app). The result carries NetEase's own lyrics too; the caller only takes what matches.
quint64 LyricsFetcher::lookupExtras(const Track &t)
{
    m_current = ++m_nextId;
    auto job = std::make_shared<Job>();
    job->id = m_current;
    job->track = t;
    job->cands = Text::candidates(t);
    job->lrcDone = job->qqDone = job->kgDone = true;
    if (job->cands.isEmpty()) {
        job->neDone = true;
        publish(job);
        return job->id;
    }
    netease(job);
    QTimer::singleShot(7000, this, [this, job] {
        if (job->finalSent)
            return;
        if (!job->neDone) {
            job->neDone = true;
            job->ne.networkError = true;
        }
        publish(job);
    });
    return job->id;
}

void LyricsFetcher::qq(const JobPtr &job)
{
    searchAll(
        job, 2, // parallel searches per provider: faster, but 3+ trips rate limits
        [](const Candidate &c) {
            QUrl u(QStringLiteral("https://c.y.qq.com/soso/fcgi-bin/client_search_cp"));
            QUrlQuery q;
            q.addQueryItem(QStringLiteral("w"), queryFor(c));
            for (const char *kv : {"format=json", "n=8", "p=1", "t=0", "new_json=1", "cr=1"}) {
                const QString s = QString::fromLatin1(kv);
                q.addQueryItem(s.section(QLatin1Char('='), 0, 0), s.section(QLatin1Char('='), 1));
            }
            u.setQuery(q);
            return u;
        },
        [job](const QJsonDocument &doc, const Candidate &c, Gather &g) {
            const QJsonObject root = doc.object();
            if (root.value(QStringLiteral("code")).toInt(0) != 0) {
                g.failed = true;
                return;
            }
            for (const auto &v : root.value(QStringLiteral("data")).toObject().value(QStringLiteral("song")).toObject()
                                     .value(QStringLiteral("list")).toArray()) {
                const QJsonObject o = v.toObject();
                QStringList artists;
                for (const auto &a : o.value(QStringLiteral("singer")).toArray())
                    artists << a.toObject().value(QStringLiteral("name")).toString();
                const double dur = o.value(QStringLiteral("interval")).toDouble();
                const double s = Text::score(c, job->track.durationSec, o.value(QStringLiteral("name")).toString(),
                                             artists.join(QLatin1Char(' ')), dur, job->track.album,
                                             o.value(QStringLiteral("album")).toObject().value(QStringLiteral("name")).toString());
                if (job->track.skip.contains(QStringLiteral("qq:") + o.value(QStringLiteral("mid")).toString()))
                    continue;
                if (s > g.score) {
                    g.score = s;
                    g.dur = dur;
                    g.id = o.value(QStringLiteral("mid")).toString();
                    g.obj = QJsonObject{{QStringLiteral("n"), o.value(QStringLiteral("name")).toString() + QLatin1Char('/') + artists.join(QLatin1Char(','))}};
                }
            }
        },
        [this, job](const Gather &g) {
            if (kDebug)
                qWarning() << "qq pick" << g.score << g.obj.value(QStringLiteral("n")).toString();
            if (g.score >= kMinScore && !g.id.isEmpty()) {
                qqLyric(job, g.id, g.score, g.dur);
            } else {
                LyricsResult r;
                r.networkError = g.failed;
                finishQq(job, r);
            }
        });
}

void LyricsFetcher::qqLyric(const JobPtr &job, const QString &mid, double conf, double dur)
{
    QUrl url(QStringLiteral("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("songmid"), mid);
    q.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    q.addQueryItem(QStringLiteral("nobase64"), QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("g_tk"), QStringLiteral("5381"));
    url.setQuery(q);
    get(job, url, [this, job, conf, dur, mid](bool ok, bool, const QByteArray &body) {
        LyricsResult r;
        r.conf = conf;
        r.srcDur = dur;
        r.sourceId = QStringLiteral("qq:") + mid;
        const QJsonObject o = QJsonDocument::fromJson(body).object();
        if (!ok || o.value(QStringLiteral("code")).toInt(0) != 0) {
            r.networkError = true;
        } else {
            const QString lrc = o.value(QStringLiteral("lyric")).toString();
            if (looksSynced(lrc)) {
                r.synced = lrc;
                r.found = true;
            }
        }
        finishQq(job, r);
    });
}

// ------------------------------------------------------------------- merge

void LyricsFetcher::finishLrclib(const JobPtr &job, const LyricsResult &r)
{
    job->lrc = r;
    job->lrcDone = true;
    publish(job);
}

void LyricsFetcher::finishKugou(const JobPtr &job, const LyricsResult &r)
{
    job->kg = r;
    job->kgDone = true;
    publish(job);
}

// ------------------------------------------------------------------ Kugou
// Plain HTTP (its TLS certificate does not validate): public lyric text only, nothing private is sent.
// Search the song, then the lyric of that exact file (hash + duration), then decode the base64 LRC.
void LyricsFetcher::kugou(const JobPtr &job)
{
    searchAll(
        job, 1,
        [](const Candidate &c) {
            QUrl u(QStringLiteral("http://mobilecdn.kugou.com/api/v3/search/song"));
            QUrlQuery q;
            q.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
            q.addQueryItem(QStringLiteral("keyword"), queryFor(c));
            q.addQueryItem(QStringLiteral("page"), QStringLiteral("1"));
            q.addQueryItem(QStringLiteral("pagesize"), QStringLiteral("8"));
            u.setQuery(q);
            return u;
        },
        [job](const QJsonDocument &doc, const Candidate &c, Gather &g) {
            const QJsonObject root = doc.object();
            if (root.value(QStringLiteral("status")).toInt(1) != 1) {
                g.failed = true;
                return;
            }
            for (const auto &v : root.value(QStringLiteral("data")).toObject().value(QStringLiteral("info")).toArray()) {
                const QJsonObject o = v.toObject();
                const double dur = o.value(QStringLiteral("duration")).toDouble();
                const double s = Text::score(c, job->track.durationSec, o.value(QStringLiteral("songname")).toString(),
                                             o.value(QStringLiteral("singername")).toString(), dur, job->track.album,
                                             o.value(QStringLiteral("album_name")).toString());
                if (job->track.skip.contains(QStringLiteral("kugou:") + o.value(QStringLiteral("hash")).toString()))
                    continue;
                if (s > g.score) {
                    g.score = s;
                    g.dur = dur;
                    g.id = o.value(QStringLiteral("hash")).toString();
                    g.obj = QJsonObject{{QStringLiteral("n"), o.value(QStringLiteral("songname")).toString()},
                                        {QStringLiteral("kw"), queryFor(c)}};
                }
            }
        },
        [this, job](const Gather &g) {
            if (kDebug)
                qWarning() << "kugou pick" << g.score << g.obj.value(QStringLiteral("n")).toString();
            if (g.score >= kMinScore && !g.id.isEmpty()) {
                QUrl u(QStringLiteral("http://lyrics.kugou.com/search"));
                QUrlQuery q;
                q.addQueryItem(QStringLiteral("ver"), QStringLiteral("1"));
                q.addQueryItem(QStringLiteral("man"), QStringLiteral("yes"));
                q.addQueryItem(QStringLiteral("client"), QStringLiteral("pc"));
                q.addQueryItem(QStringLiteral("keyword"), g.obj.value(QStringLiteral("kw")).toString());
                q.addQueryItem(QStringLiteral("duration"), QString::number(qint64(g.dur * 1000)));
                q.addQueryItem(QStringLiteral("hash"), g.id);
                u.setQuery(q);
                const double conf = g.score, dur = g.dur;
                const QString hash = g.id;
                get(job, u, [this, job, conf, dur, hash](bool ok, bool, const QByteArray &body) {
                    const QJsonArray cands = QJsonDocument::fromJson(body).object().value(QStringLiteral("candidates")).toArray();
                    if (!ok || cands.isEmpty()) {
                        LyricsResult r;
                        r.networkError = !ok;
                        finishKugou(job, r);
                        return;
                    }
                    const QJsonObject c0 = cands.first().toObject();
                    QUrl d(QStringLiteral("http://lyrics.kugou.com/download"));
                    QUrlQuery dq;
                    dq.addQueryItem(QStringLiteral("ver"), QStringLiteral("1"));
                    dq.addQueryItem(QStringLiteral("client"), QStringLiteral("pc"));
                    dq.addQueryItem(QStringLiteral("id"), c0.value(QStringLiteral("id")).toVariant().toString());
                    dq.addQueryItem(QStringLiteral("accesskey"), c0.value(QStringLiteral("accesskey")).toString());
                    dq.addQueryItem(QStringLiteral("fmt"), QStringLiteral("lrc"));
                    dq.addQueryItem(QStringLiteral("charset"), QStringLiteral("utf8"));
                    d.setQuery(dq);
                    get(job, d, [this, job, conf, dur, hash](bool ok2, bool, const QByteArray &b2) {
                        LyricsResult r;
                        r.conf = conf;
                        r.srcDur = dur;
                        r.sourceId = QStringLiteral("kugou:") + hash;
                        QString lrc = QString::fromUtf8(QByteArray::fromBase64(
                            QJsonDocument::fromJson(b2).object().value(QStringLiteral("content")).toString().toLatin1()));
                        if (lrc.startsWith(QChar(0xFEFF)))
                            lrc.remove(0, 1);
                        if (ok2 && looksSynced(lrc)) {
                            r.synced = lrc;
                            r.found = true;
                        } else {
                            r.networkError = !ok2;
                        }
                        finishKugou(job, r);
                    });
                });
            } else {
                LyricsResult r;
                r.networkError = g.failed;
                finishKugou(job, r);
            }
        });
}

void LyricsFetcher::finishQq(const JobPtr &job, const LyricsResult &r)
{
    job->qq = r;
    job->qqDone = true;
    publish(job);
}

void LyricsFetcher::finishNetease(const JobPtr &job, const LyricsResult &r)
{
    job->ne = r;
    job->neDone = true;
    publish(job);
}

QHash<QString, qint64> &LyricsFetcher::nextSlot()
{
    static QHash<QString, qint64> hostSlots;
    return hostSlots;
}

void LyricsFetcher::ytmusic(const JobPtr &job)
{
    auto finish = [this, job](const QString &text) {
        if (job->id != m_current || job->ytDone)
            return;
        job->ytDone = true;
        if (!text.trimmed().isEmpty()) {
            job->yt.plain = text;
            job->yt.found = true;
            job->yt.conf = 1.5; // by video id: no matching involved
            job->yt.sourceId = QStringLiteral("ytmusic:") + job->track.id;
        }
        publish(job);
    };
    QTimer::singleShot(6000, this, [finish] { finish(QString()); });
    const QJsonObject ctx{{QStringLiteral("client"), QJsonObject{{QStringLiteral("clientName"), QStringLiteral("WEB_REMIX")},
                                                                  {QStringLiteral("clientVersion"), QStringLiteral("1.20240101.01.00")},
                                                                  {QStringLiteral("hl"), QStringLiteral("en")}}}};
    auto post = [this](const QString &path, const QJsonObject &body, std::function<void(const QJsonObject &)> cb) {
        QNetworkRequest req(QUrl(QStringLiteral("https://music.youtube.com/youtubei/v1/%1?prettyPrint=false").arg(path)));
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (X11; Linux x86_64) lyric-widget/0.3"));
        req.setRawHeader("Origin", "https://music.youtube.com");
        req.setTransferTimeout(5000);
        QNetworkReply *reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [reply, cb = std::move(cb)] {
            reply->deleteLater();
            cb(reply->error() == QNetworkReply::NoError ? QJsonDocument::fromJson(reply->readAll()).object() : QJsonObject());
        });
    };
    // the video's "Lyrics" tab has its own browse id; that page holds the text
    post(QStringLiteral("next"), {{QStringLiteral("context"), ctx}, {QStringLiteral("videoId"), job->track.id}},
         [post, ctx, finish](const QJsonObject &o) {
             QString browseId;
             const QJsonArray tabs = o.value(QStringLiteral("contents")).toObject()
                 .value(QStringLiteral("singleColumnMusicWatchNextResultsRenderer")).toObject()
                 .value(QStringLiteral("tabbedRenderer")).toObject()
                 .value(QStringLiteral("watchNextTabbedResultsRenderer")).toObject().value(QStringLiteral("tabs")).toArray();
             for (const QJsonValue &t : tabs) {
                 const QString id = t.toObject().value(QStringLiteral("tabRenderer")).toObject().value(QStringLiteral("endpoint")).toObject()
                                        .value(QStringLiteral("browseEndpoint")).toObject().value(QStringLiteral("browseId")).toString();
                 if (id.startsWith(QLatin1String("MPLYt")))
                     browseId = id;
             }
             if (browseId.isEmpty()) {
                 finish(QString());
                 return;
             }
             post(QStringLiteral("browse"), {{QStringLiteral("context"), ctx}, {QStringLiteral("browseId"), browseId}},
                  [finish](const QJsonObject &b) {
                      const QJsonArray sections = b.value(QStringLiteral("contents")).toObject()
                          .value(QStringLiteral("sectionListRenderer")).toObject().value(QStringLiteral("contents")).toArray();
                      QString text;
                      for (const QJsonValue &s : sections) {
                          const QJsonArray runs = s.toObject().value(QStringLiteral("musicDescriptionShelfRenderer")).toObject()
                                                      .value(QStringLiteral("description")).toObject().value(QStringLiteral("runs")).toArray();
                          for (const QJsonValue &r : runs)
                              text += r.toObject().value(QStringLiteral("text")).toString();
                      }
                      finish(text);
                  });
         });
}

void LyricsFetcher::publish(const JobPtr &job)
{
    // whichever provider it came from, lyrics in the wrong language for this version are not an answer
    if (job->track.onlySynced)
        for (LyricsResult *r : {&job->lrc, &job->ne, &job->qq, &job->kg})
            if (r->found && r->synced.isEmpty())
                *r = LyricsResult();
    for (LyricsResult *r : {&job->lrc, &job->ne, &job->qq, &job->kg, &job->yt})
        if (r->found && Text::langMismatch(r->synced.isEmpty() ? r->plain : r->synced, job->track.lang))
            *r = LyricsResult();
    const LyricsResult &l = job->lrc, &n = job->ne, &q = job->qq, &k = job->kg, &y = job->yt;
    const bool mainDone = job->lrcDone && job->neDone && job->qqDone && job->kgDone;
    const bool allDone = mainDone && (!job->ytStarted || job->ytDone);
    // Latin lyrics from LRCLIB need nothing from the others: don't wait for them...
    // ...unless the song is CJK: LRCLIB also holds user-made romaji-only copies, which are not
    // the lyrics we want on the main line.
    const bool cjkTrack = Text::hasNonLatin(job->track.title + job->track.artist);
    const bool lrcEnough = job->lrcDone && !l.synced.isEmpty() && l.conf >= 0.9
                           && !Text::hasNonLatin(l.synced) && !cjkTrack && !Text::incompleteLrc(l.synced);
    // The provider that usually has this artist's lyrics: once it answers with a clean, confident
    // synced result there is no point waiting for the others.
    const LyricsResult *fav = job->track.prefer == QLatin1String("lrclib") ? &l
                              : job->track.prefer == QLatin1String("netease") ? &n
                              : job->track.prefer == QLatin1String("qq") ? &q
                              : job->track.prefer == QLatin1String("kugou") ? &k : nullptr;
    const bool favDone = fav == &l ? job->lrcDone : fav == &n ? job->neDone : fav == &q ? job->qqDone
                         : fav == &k ? job->kgDone : false;
    const bool favEnough = fav && favDone && !fav->synced.isEmpty() && fav->conf >= 0.9
                           && !Text::incompleteLrc(fav->synced) && (fav != &l || !cjkTrack);
    const bool haveSynced = (job->lrcDone && !l.synced.isEmpty()) || (job->neDone && !n.synced.isEmpty())
                            || (job->qqDone && !q.synced.isEmpty()) || (job->kgDone && !k.synced.isEmpty());
    if (job->finalSent)
        return; // later finishers are ignored once the final answer is out
    // Nobody has timed lyrics: YouTube Music's own text for the playing video is the last resort
    if (mainDone && !haveSynced && !job->ytStarted && !job->track.onlySynced && job->track.id.size() == 11) {
        job->ytStarted = true;
        ytmusic(job);
        return;
    }
    if (!allDone && !lrcEnough && !favEnough && !haveSynced)
        return;

    // Source order: LRCLIB, NetEase, QQ. Synced beats plain; instrumental flag only from LRCLIB.
    const bool romajiCopy = cjkTrack && !Text::hasNonLatin(l.synced)
                            && (Text::hasNonLatin(n.synced) || Text::hasNonLatin(q.synced) || Text::hasNonLatin(k.synced));
    // Best match wins, whichever provider it came from: synced first, then plain text.
    const LyricsResult *pick = nullptr;
    for (const LyricsResult *r : {&l, &n, &q, &k}) {
        if (r->synced.isEmpty() || (r == &l && romajiCopy))
            continue;
        // a copy with a missing verse only wins when no complete one exists
        const bool rBad = Text::incompleteLrc(r->synced);
        if (!pick) { pick = r; continue; }
        const bool pBad = Text::incompleteLrc(pick->synced);
        if (rBad != pBad ? pBad : r->conf > pick->conf)
            pick = r;
    }
    if (!pick && l.instrumental)
        pick = &l;
    if (!pick)
        for (const LyricsResult *r : {&l, &n, &q, &k, &y})
            if (!r->plain.isEmpty() && (!pick || r->conf > pick->conf))
                pick = r;
    // Lyrics and romanization must come from the same version, or lines pair up wrongly and the
    // gaps get filled by the rougher local conversion. If NetEase's romanization fits the chosen
    // lyrics poorly (extra translation lines, different line breaks) but fits NetEase's own lyrics,
    // use NetEase's lyrics.
    if (pick && pick != &n && !n.roman.isEmpty() && Text::isCjk(n.synced) && Text::isCjk(pick->synced)) {
        const auto orig = Lrc::parse(pick->synced);
        int hit = 0, total = 0;
        RomanAlign::align(orig, Lrc::parse(n.roman), &hit);
        for (const LyricLine &ln : orig)
            total += !ln.text.isEmpty();
        if (kDebug)
            qWarning() << "romanization fits the chosen lyrics:" << hit << "/" << total;
        if (total > 0 && hit < 0.85 * total)
            pick = &n;
    }
    LyricsResult out = pick ? *pick : n;
    out.provider = pick == &l ? QStringLiteral("lrclib") : pick == &q ? QStringLiteral("qq")
                   : pick == &k ? QStringLiteral("kugou") : pick == &y ? QStringLiteral("ytmusic") : QStringLiteral("netease");
    // Romanization, best first: NetEase's own, then a human-made romaji copy from LRCLIB; the
    // controller aligns it line by line and fills any gaps locally.
    if (!lrcEnough && !n.roman.isEmpty())
        out.roman = n.roman;
    else if (out.roman.isEmpty() && pick != &l && !l.roman.isEmpty())
        out.roman = l.roman;
    else if (out.roman.isEmpty() && romajiCopy && Text::isCjk(out.synced))
        out.roman = l.synced; // LRCLIB only had the romaji copy; the script came from NetEase/QQ
    // A provider that timed out (QQ often does) must not turn "nobody has this song" into "can't reach the
    // service": only when no provider gave a definite answer is it a network problem.
    int answered = 0;
    for (const LyricsResult *r : {&l, &n, &q, &k})
        answered += !r->networkError;
    out.networkError = allDone && !out.found && answered == 0;
    // A CJK song whose NetEase lookup failed has no provider romanization *because of the failure*:
    // not a final answer, so it must not be cached; the controller retries.
    // (also when NetEase answered with no usable song: the same lookup often succeeds a moment later)
    out.degraded = allDone && cjkTrack && out.roman.isEmpty() && !n.found;

    // A provider failed and we only have unsynced text: not an answer, so it must not be
    // cached; the controller shows it and retries.
    const bool incomplete = allDone && out.synced.isEmpty() && answered < 2
                            && (l.networkError || n.networkError || q.networkError || k.networkError);
    const bool final = (allDone || lrcEnough || favEnough) && !incomplete;
    if (kDebug)
        qWarning() << "publish" << job->id << "final" << final << "allDone" << allDone << "synced" << out.synced.size() << "conf" << out.conf;
    job->published = true;
    job->finalSent = allDone || lrcEnough || favEnough;
    // Nothing for "artist + title": divide down to the broader guesses (title alone with a tight length match,
    // letters-joined artist...) under the same request, instead of giving up
    if (final && !out.found && !out.networkError && !job->track.loose) {
        auto again = std::make_shared<Job>();
        again->id = job->id;
        again->track = job->track;
        again->track.loose = true;
        again->cands = Text::candidates(again->track);
        if (again->cands != job->cands) {
            start(again);
            return;
        }
    }
    emit result(job->id, out, final);
}
