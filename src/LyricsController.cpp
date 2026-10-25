#include "LyricsController.h"

#include "GapFill.h"
#include "RomanAlign.h"
#include "Romanizer.h"
#include "Text.h"

#include <QDebug>
#include <QDir>
#include <QImage>
#include <QProcessEnvironment>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <algorithm>
#include <cmath>

namespace {

// YouTube: watch?v=ID. Spotify: /track/ID. Stable per recording, so a song and its music video
// (different uploads, different timing) never share a cache entry.
QString trackId(const QString &url)
{
    const QUrl u(url);
    if (u.host().contains(QLatin1String("youtube")))
        return QUrlQuery(u).queryItemValue(QStringLiteral("v"));
    if (u.host().contains(QLatin1String("spotify")))
        return u.path().section(QLatin1Char('/'), -1);
    return {};
}

// "作词 : x", "Composer: y" credit rows that NetEase puts at 00:00.
bool isCredit(const QString &t)
{
    static const QRegularExpression re(
        QStringLiteral(R"(^\s*(作词|作曲|编曲|制作人|作詞|編曲|词|曲|歌手|演唱|lyrics?|music|compos(?:ed|er)|arrange[dr]?|produce[dr]?|written)(\s+by)?\s*[:：])"),
        QRegularExpression::CaseInsensitiveOption);
    return re.match(t).hasMatch();
}

} // namespace

LyricsController::LyricsController(QObject *parent) : QObject(parent), m_watcher(this), m_fetcher(this)
{
    m_status = QStringLiteral("Waiting for Spotify or Chrome…");

    m_timer.setSingleShot(true);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &LyricsController::resync);

    connect(&m_watcher, &PlayerWatcher::trackChanged, this, &LyricsController::onTrackChanged);
    connect(&m_watcher, &PlayerWatcher::timingChanged, this, &LyricsController::resync);
    connect(&m_watcher, &PlayerWatcher::timingChanged, this, &LyricsController::playingChanged);
    connect(&m_watcher, &PlayerWatcher::timingChanged, this, &LyricsController::updateAudio);

    m_audio.setPositionSource([this]() -> qint64 {
        const MprisPlayer *p = m_watcher.active();
        return p ? p->positionUs() / 1000 : 0;
    });
    connect(&m_audio, &AudioListener::beat, this, &LyricsController::beat);
    connect(&m_audio, &AudioListener::tempoChanged, this, &LyricsController::bpmChanged);
    m_audioSyncTimer.setInterval(8000);
    connect(&m_audioSyncTimer, &QTimer::timeout, this, &LyricsController::checkAudioSync);

    m_preTimer.setSingleShot(true);
    connect(&m_preTimer, &QTimer::timeout, this, [this] {
        const MprisPlayer *p = m_watcher.active();
        if (m_prefetchCount <= 0 || !p)
            return;
        // Next songs not cached yet, capped to the "look ahead" setting.
        auto take = [this](const QList<Track> &next) {
            m_preQueue.clear();
            for (const Track &t : next.mid(0, m_prefetchCount))
                if (!m_store.get(QStringLiteral("id:") + t.id))
                    m_preQueue << t;
            prefetchNext();
        };
        if (p->service().contains(QLatin1String("spotify"))) {
            m_spotify.fetchQueue([take](bool ok, const QList<Track> &next) { if (ok) take(next); });
        } else if (m_browser.enabled()) { // YouTube Music, via the Chrome extension
            const QList<Track> next = m_browser.latest();
            if (!next.isEmpty())
                take(next);
        }
    });
    connect(&m_browser, &BrowserQueue::received, this, [this] {
        if (!m_preTimer.isActive() && !m_lines.isEmpty()) // current song already has its lyrics
            m_preTimer.start(3000);
    });
    m_preWatch.setSingleShot(true); // a throttled provider may never finish a lookup
    connect(&m_preWatch, &QTimer::timeout, this, [this] { m_preId = 0; m_preTimer.start(1); });
    connect(&m_pre, &LyricsFetcher::result, this, [this](quint64 id, const LyricsResult &r, bool final) {
        if (id != m_preId || !final)
            return;
        m_preWatch.stop();
        m_preId = 0;
        // same policy as the foreground: only settled answers go into the cache
        const bool romajiOnly = !r.synced.isEmpty() && !Text::hasNonLatin(r.synced)
                                && Text::hasNonLatin(m_preQueueCur.title + m_preQueueCur.artist);
        const bool settled = !r.networkError && !r.degraded && !romajiOnly && (!r.synced.isEmpty() || r.instrumental || !r.found);
        if (settled) {
            StoredLyrics s;
            s.found = r.found; s.instrumental = r.instrumental; s.synced = r.synced;
            s.plain = r.plain; s.roman = r.roman; s.srcDur = r.srcDur; s.provider = r.provider; s.words = r.words;
            m_store.put(m_preKey, s);
            noteWin(m_preQueueCur, r);
        }
        QTimer::singleShot(5000, this, [this] { prefetchNext(); }); // gentle: one song per 5 s
    });
    connect(&m_fetcher, &LyricsFetcher::result, this, &LyricsController::onResult);

    // start discovery once the event loop is running (QML object fully constructed)
    QTimer::singleShot(0, this, [this] { m_watcher.start(); });
}

void LyricsController::setOffsetMs(int ms)
{
    if (ms == m_offsetMs)
        return;
    m_offsetMs = ms;
    emit offsetMsChanged();
    resync();
}

void LyricsController::nudge(int deltaMs)
{
    m_trackOffsetMs = deltaMs == 0 ? 0 : m_trackOffsetMs + deltaMs;
    if (!m_key.isEmpty())
        m_store.setOffset(m_key, m_trackOffsetMs, m_provider);
    emit offsetMsChanged();
    resync();
}

void LyricsController::setSuspended(bool on)
{
    if (on == m_suspended)
        return;
    m_suspended = on;
    emit suspendedChanged();
    updateAudio();
    if (on) {
        m_timer.stop();
        m_preTimer.stop();
        m_preWatch.stop();
        m_preQueue.clear();
        m_preId = 0;
        if (m_kakasi.state() != QProcess::NotRunning)
            m_kakasi.kill();
        return;
    }
    // Back on screen: look at whatever is playing now and catch up to the right line.
    m_key.clear();
    onTrackChanged();
}

void LyricsController::setPrefetchCount(int n)
{
    n = std::clamp(n, 0, 5); // the safe range: more than 5 just trips provider rate limits
    if (n == m_prefetchCount)
        return;
    m_prefetchCount = n;
    emit prefetchCountChanged();
    schedulePrefetch();
}

// Called once the current song has its lyrics: look ahead in the Spotify queue, a little later.
void LyricsController::schedulePrefetch()
{
    if (m_suspended)
        return;
    m_spotify.reload(); // the settings window may have just connected the account
    if (m_prefetchCount > 0 && (m_spotify.canFetch() || m_browser.enabled()))
        m_preTimer.start(5000);
}

void LyricsController::prefetchNext()
{
    if (m_preId != 0 || m_preQueue.isEmpty())
        return;
    m_preQueueCur = m_preQueue.takeFirst();
    m_preQueueCur.prefer = favouriteFor(m_preQueueCur);
    m_preKey = QStringLiteral("id:") + m_preQueueCur.id;
    if (m_store.get(m_preKey)) { // cached meanwhile
        prefetchNext();
        return;
    }
    m_preWatch.start(30000);
    const MprisPlayer *pl = m_watcher.active();
    if (m_spotify.appQueue() && pl && pl->service().contains(QLatin1String("spotify"))) {
        // ask the Spotify app first (exact, fast); the web providers only when it has nothing
        const Track cur = m_preQueueCur;
        const QString key = m_preKey;
        m_preId = quint64(-1);
        m_spotify.fetchLyrics(cur.id, [this, cur, key](bool ok, const SpotifyAccount::AppLyrics &l) {
            if (key != m_preKey || m_preId != quint64(-1))
                return; // the user moved on
            if (ok && !l.synced.isEmpty()) {
                StoredLyrics s;
                s.found = true; s.synced = l.synced; s.plain = l.plain; s.roman = l.roman;
                s.srcDur = cur.durationSec; s.provider = QStringLiteral("spotify");
                m_store.put(key, s);
                m_preWatch.stop();
                m_preId = 0;
                QTimer::singleShot(300, this, [this] { prefetchNext(); });
                return;
            }
            m_preId = m_pre.lookup(cur);
        });
        return;
    }
    m_preId = m_pre.lookup(m_preQueueCur);
}

void LyricsController::setStatus(const QString &s)
{
    if (s == m_status)
        return;
    m_status = s;
    emit statusChanged();
}

void LyricsController::setIndex(int i)
{
    if (i == m_index)
        return;
    m_index = i;
    // How long this line stays on screen: the smaller of the gap before it and the gap after it,
    // so a slow line followed by a quick one still gets a short animation.
    qint64 gap = 60000;
    if (i >= 0 && i < m_lrc.size()) {
        if (i > 0)
            gap = std::min(gap, m_lrc[i].timeMs - m_lrc[i - 1].timeMs);
        if (i + 1 < m_lrc.size())
            gap = std::min(gap, m_lrc[i + 1].timeMs - m_lrc[i].timeMs);
        if (i == 0 && m_lrc.size() < 2)
            gap = 2000;
    } else {
        gap = 2000;
    }
    m_lineGapMs = int(gap * m_timeScale);
    emit currentIndexChanged();
}

void LyricsController::clearLyrics()
{
    ++m_applyGen; // drop any pending kanji romanization
    m_timer.stop();
    m_lrc.clear();
    m_lines.clear();
    m_roman.clear();
    m_srcLrc.clear();
    m_srcText.clear();
    m_srcRoman.clear();
    m_hasRoman = false;
    m_synced = false;
    m_index = -1;
    emit linesChanged();
    emit currentIndexChanged();
}

void LyricsController::onTrackChanged()
{
    if (m_suspended)
        return; // picked up again by setSuspended(false)
    const MprisPlayer *p = m_watcher.active();
    const bool nowIdle = !p || p->title().isEmpty();
    if (nowIdle != m_idle) {
        m_idle = nowIdle;
        emit idleChanged();
    }
    updateArt(nowIdle ? QString() : p->artUrl());
    if (nowIdle) {
        m_key.clear();
        m_title.clear();
        m_artist.clear();
        m_requestId = 0;
        clearLyrics();
        emit trackInfoChanged();
        setStatus(QStringLiteral("Waiting for Spotify or Chrome…"));
        return;
    }

    Track t;
    t.title = p->title();
    t.artist = p->artist();
    t.album = p->album();
    t.id = trackId(p->url());
    t.durationSec = int(p->lengthUs() / 1'000'000);

    const QString key = !t.id.isEmpty()
                            ? QStringLiteral("id:") + t.id
                            : Text::norm(t.artist) + QLatin1Char('|') + Text::norm(t.title)
                                  + QLatin1Char('|') + QString::number(t.durationSec);
    if (key == m_key)
        return; // same song (e.g. metadata refresh): keep what we have
    m_preQueue.clear(); // the user moved on: drop any look-ahead in progress
    m_preId = 0;
    m_preTimer.stop();
    m_key = key;
    m_track = t;
    m_autoSynced = false;
    m_readingLines.clear();
    m_audio.reset();
    m_trackOffsetMs = m_store.offset(key); // an automatic correction may replace this in apply()
    m_gapSec = 0;
    emit offsetMsChanged();
    m_retries = 0;

    const auto cands = Text::candidates(t);
    m_title = cands.isEmpty() ? t.title : cands.first().title;
    m_artist = cands.isEmpty() ? t.artist : cands.first().artist;
    emit trackInfoChanged();
    clearLyrics();

    if (Text::notASong(t, p->url())) {
        m_requestId = 0;
        setStatus(QStringLiteral("Not a song — no lyrics to look up"));
        return;
    }
    if (const auto cached = m_store.get(key)) {
        m_requestId = 0; // a late answer for the previous song must not land on this one
        apply(*cached);
        schedulePrefetch();
        return;
    }
    setStatus(QStringLiteral("Loading lyrics…"));
    m_track.prefer = favouriteFor(t);
    // Spotify songs: ask the Spotify app itself first. It shows lyrics for the exact track id, so there is
    // no title/artist matching to get wrong, and it answers in a fraction of a second.
    if (p->service().contains(QLatin1String("spotify")) && m_spotify.appQueue() && !t.id.isEmpty()) {
        const QString k = m_key;
        m_requestId = 0;
        m_spotify.fetchLyrics(t.id, [this, k](bool ok, const SpotifyAccount::AppLyrics &l) {
            if (k != m_key)
                return; // skipped to another song meanwhile
            if (!ok || l.synced.isEmpty()) {
                startLookup(); // the app has none (or is not reachable): the web providers
                return;
            }
            StoredLyrics s;
            s.found = true;
            s.synced = l.synced;
            s.plain = l.plain;
            s.roman = l.roman;
            s.srcDur = m_track.durationSec;
            s.provider = QStringLiteral("spotify");
            m_store.put(k, s);
            apply(s);
            schedulePrefetch();
        });
        return;
    }
    startLookup();
}

void LyricsController::onResult(quint64 id, const LyricsResult &r, bool final)
{
    if (id != m_requestId)
        return; // a newer track superseded this request

    if (r.networkError)
        setStatus(QStringLiteral("Couldn't reach the lyrics service — retrying…"));
    // A provider failed, or we only got unsynced text: try again quietly in a few seconds (the
    // lines on screen stay put). Such answers aren't cached until the retries are used up, so
    // one lost lookup can't pin a song to unsynced text.
    const bool romajiOnly = !r.synced.isEmpty() && !Text::hasNonLatin(r.synced)
                            && Text::hasNonLatin(m_track.title + m_track.artist); // user-made romaji copy
    const bool weak = romajiOnly || r.degraded || (r.synced.isEmpty() && !r.instrumental
                                     && (r.networkError || r.found || !final)); // found = plain text only
    const bool retry = weak && m_retries < 3;
    if (retry) {
        ++m_retries;
        const QString key = m_key;
        QTimer::singleShot(6000 * m_retries * m_retries, this, [this, key] { // 6 s, 24 s, 54 s
            if (key == m_key && !m_suspended)
                m_requestId = m_fetcher.lookup(m_track);
        });
    }
    if (r.networkError)
        return;
    StoredLyrics s;
    s.found = r.found;
    s.instrumental = r.instrumental;
    s.synced = r.synced;
    s.plain = r.plain;
    s.roman = r.roman;
    s.srcDur = r.srcDur;
    s.provider = r.provider;
    s.words = r.words;
    if (final && !retry) {
        m_store.put(m_key, s);
        noteWin(m_track, r);
        schedulePrefetch();
    }
    apply(s);
}

void LyricsController::apply(const StoredLyrics &s)
{
    m_srcLrc.clear();
    m_srcText.clear();
    m_srcRoman.clear();
    m_synced = false;
    m_syncedRaw = s.synced;
    m_filled = 0;
    m_provider = s.provider;
    // Self-correcting timing: a song the user never nudged starts with the delay their nudges have
    // shown this provider's timestamps usually have.
    if (!m_store.hasOffset(m_key) && !s.provider.isEmpty()) {
        const int learned = m_store.learnedOffset(s.provider);
        if (learned != m_trackOffsetMs) {
            m_trackOffsetMs = learned;
            emit offsetMsChanged();
        }
    }

    if (s.instrumental) {
        setStatus(QStringLiteral("Instrumental"));
    } else if (!s.synced.isEmpty()) {
        m_srcLrc = Lrc::parse(s.synced);
        m_srcLrc.erase(std::remove_if(m_srcLrc.begin(), m_srcLrc.end(),
                                      [](const LyricLine &l) { return isCredit(l.text); }),
                       m_srcLrc.end());
        if (Text::incompleteLrc(s.synced))
            m_filled = GapFill::fill(m_srcLrc, s.plain);
        for (const LyricLine &l : std::as_const(m_srcLrc))
            m_srcText << l.text;
        m_synced = !m_srcLrc.isEmpty();
    }
    if (!m_synced && !s.instrumental && !s.plain.isEmpty()) {
        m_srcLrc.clear();
        m_srcText = s.plain.split(QLatin1Char('\n'));
        setStatus(QStringLiteral("Unsynced lyrics"));
    } else if (m_synced) {
        setStatus(QString());
    } else if (!s.instrumental) {
        setStatus(QStringLiteral("No lyrics found"));
    }

    // Romanization: provider's (accurate, handles kanji) first, local rules for the gaps.
    if (m_synced && !s.roman.isEmpty())
        m_srcRoman = RomanAlign::align(m_srcLrc, Lrc::parse(s.roman));
    m_srcRoman.resize(m_srcText.size());
    bool japaneseSong = false;
    for (const QString &l : std::as_const(m_srcText))
        for (const QChar ch : l)
            japaneseSong |= (ch.unicode() >= 0x3041 && ch.unicode() <= 0x30FF);
    m_localRoman.assign(m_srcText.size(), false);
    for (qsizetype i = 0; i < m_srcText.size(); ++i) {
        if (m_srcRoman[i] == m_srcText[i])
            m_srcRoman[i].clear();
        if (m_srcRoman[i].isEmpty()) {
            m_localRoman[i] = true; // not from the provider: the helper may do better
            m_srcRoman[i] = Romanizer::line(m_srcText[i], japaneseSong);
        }
    }

    // Matched version's length vs the playing one: a gap hints at an intro/outro (music video,
    // remix) that shifts the timing. Small gaps are normal encoder differences.
    m_gapSec = 0;
    if (s.srcDur > 0 && m_track.durationSec > 0) {
        const int gap = m_track.durationSec - int(std::lround(s.srcDur));
        m_gapSec = std::abs(gap) >= 4 ? gap : 0;
    }

    // Sped-up / slowed version of a song: stretch the timestamps to the playing length
    m_timeScale = 1;
    if (s.srcDur > 0 && m_track.durationSec > 0 && Text::tempoVariant(m_track.title) != 0) {
        const double k = m_track.durationSec / s.srcDur;
        if (k > 0.5 && k < 1.6 && std::abs(k - 1) > 0.03) {
            m_timeScale = k;
            m_gapSec = 0; // the length difference is explained
        }
    }

    parseWords(s.words);
    layer();
    m_index = -1;
    emit linesChanged();
    emit currentIndexChanged();
    resync();
    romanizeKanji();
    maybeFetchReading(s);
}

// Builds what is shown from the per-line source data, handling layered lyrics:
//  - lines with the same timestamp (main + harmony, original + translation) show together;
//  - a "(backing)" line that starts while the main line is still being sung shows together with
//    that main line, instead of replacing it.
// m_lrc/m_lines/m_roman are then one entry per on-screen state, so the timer logic is unchanged.
void LyricsController::layer()
{
    m_lrc.clear();
    m_lines.clear();
    m_roman.clear();
    m_entrySrc.clear();
    if (!m_synced) {
        m_lines = m_srcText;
        m_roman = m_srcRoman;
    } else {
        static const QRegularExpression backing(QStringLiteral(R"(^\s*[\(（].*[\)）]\s*$)"));
        struct Part { QString text, roman; };
        QVector<QVector<Part>> entries;
        QVector<Part> main; // parts of the latest non-backing entry
        m_entrySrc.clear();
        for (qsizetype i = 0; i < m_srcLrc.size(); ++i) {
            const qint64 t = m_srcLrc[i].timeMs;
            const Part p{m_srcText[i], m_srcRoman[i]};
            const bool isBacking = backing.match(p.text).hasMatch();
            if (!entries.isEmpty() && !p.text.isEmpty() && !entries.last().isEmpty()
                && t - m_lrc.last().timeMs <= 100) {
                entries.last().push_back(p); // same moment: show together
                m_entrySrc.last() = -1;
                if (!isBacking)
                    main = entries.last();
            } else if (isBacking && !main.isEmpty()) {
                entries.push_back(main + QVector<Part>{p}); // keep the main line up, add backing
                m_entrySrc.push_back(-1);
                m_lrc.push_back({t, QString()});
                continue;
            } else {
                entries.push_back({p});
                m_entrySrc.push_back(int(i));
                m_lrc.push_back({t, QString()});
                main = (isBacking || p.text.isEmpty()) ? QVector<Part>() : entries.last();
            }
        }
        for (const auto &e : std::as_const(entries)) {
            QStringList texts, roms;
            bool anyRoman = false;
            for (const Part &p : e) {
                texts << p.text;
                roms << (p.roman.isEmpty() ? p.text : p.roman);
                anyRoman |= !p.roman.isEmpty();
            }
            m_lines << texts.join(QLatin1Char('\n'));
            m_roman << (anyRoman ? roms.join(QLatin1Char('\n')) : QString());
        }
        for (qsizetype i = 0; i < m_lrc.size(); ++i)
            m_lrc[i].text = m_lines[i];
    }
    m_hasRoman = std::any_of(m_roman.cbegin(), m_roman.cend(), [](const QString &r) { return !r.isEmpty(); });
}

// Kanji lines have no local rule-based romanization. If `kakasi` is installed, convert them in
// one async batch (a few ms) and fill the gaps. Dictionary-based, not context-aware: readings of
// some words will be off, which is why provider romanization always wins.
void LyricsController::romanizeKanji()
{
    const quint64 gen = ++m_applyGen;
    if (m_kakasi.state() != QProcess::NotRunning) {
        m_kakasi.disconnect(this);
        m_kakasi.kill();
        m_kakasi.waitForFinished(200);
    }
    // A song counts as Japanese if any line has kana; then kanji-only lines are Japanese too.
    bool japanese = false;
    for (const QString &l : std::as_const(m_srcText))
        for (const QChar ch : l)
            japanese |= (ch.unicode() >= 0x3041 && ch.unicode() <= 0x30FF);
    if (!japanese)
        return;

    // Best converter: MeCab + UniDic in the private Python environment (setup-romaji.sh). It reads
    // kanji in context and gets particles right, so it redoes every line the provider didn't
    // romanize. Without it, kakasi fills just the kanji lines that have nothing.
    const QString python = QStandardPaths::findExecutable(
        QStringLiteral("python"), {QDir::homePath() + QStringLiteral("/.local/share/lyric-widget/venv/bin")});
    const QString script = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                  QStringLiteral("lyric-widget/romaji.py"));
    const bool mecab = !python.isEmpty() && !script.isEmpty();

    QList<qsizetype> todo;
    QByteArray input;
    for (qsizetype i = 0; i < m_srcText.size(); ++i) {
        if (m_srcText[i].isEmpty() || (mecab ? !m_localRoman[i] : !m_srcRoman[i].isEmpty()))
            continue;
        todo << i;
        const QString text = (mecab || !m_readingLines.isEmpty()) && i < m_readingLines.size() && !m_readingLines[i].isEmpty()
                                 ? m_readingLines[i] : m_srcText[i];
        input += (mecab ? text : Romanizer::prepareJapanese(text)).toUtf8().replace('\n', ' ') + '\n';
    }
    if (todo.isEmpty())
        return;

    connect(&m_kakasi, &QProcess::finished, this, [this, gen, todo, mecab] {
        m_kakasi.disconnect(this);
        if (gen != m_applyGen)
            return; // another track was applied meanwhile
        const QStringList out = QString::fromUtf8(m_kakasi.readAllStandardOutput()).split(QLatin1Char('\n'));
        if (out.size() < todo.size())
            return;
        for (qsizetype k = 0; k < todo.size(); ++k) {
            const QString r = Romanizer::cleanRoman(out[k]);
            if (!mecab || !r.isEmpty())
                m_srcRoman[todo[k]] = r;
        }
        if (!m_readingLines.isEmpty())
            persistRoman();
        layer();
        emit linesChanged();
    });
    connect(&m_kakasi, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            qWarning("lyric-widget: 'kakasi' not installed; kanji lines stay without romanization");
    });
    if (mecab) {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert(QStringLiteral("PYTHONUTF8"), QStringLiteral("1")); // plasmashell may run in the C locale
        m_kakasi.setProcessEnvironment(env);
        m_kakasi.start(python, {script});
        m_kakasi.write(input);
        m_kakasi.closeWriteChannel();
        return;
    }
    m_kakasi.start(QStringLiteral("kakasi"),
                   {QStringLiteral("-iutf8"), QStringLiteral("-outf8"), QStringLiteral("-Ja"),
                    QStringLiteral("-Ha"), QStringLiteral("-Ka"), QStringLiteral("-Ea"),
                    QStringLiteral("-s"), QStringLiteral("-rhepburn")});
    m_kakasi.write(input);
    m_kakasi.closeWriteChannel();
}

// Compute the current line from the interpolated player position, then arm a
// single-shot timer for exactly the next line. Nothing runs between lines, and
// nothing runs at all while paused.
void LyricsController::resync()
{
    m_timer.stop();
    if (m_suspended)
        return;
    if (!m_synced || m_lrc.isEmpty())
        return;
    const MprisPlayer *p = m_watcher.active();
    if (!p)
        return;

    const qint64 posMs = positionMs(p);
    const auto it = std::upper_bound(m_lrc.cbegin(), m_lrc.cend(), posMs,
                                     [](qint64 t, const LyricLine &l) { return t < l.timeMs; });
    const int idx = int(it - m_lrc.cbegin()) - 1; // -1 = before the first line
    setIndex(idx);

    if (!p->playing())
        return;
    if (it != m_lrc.cend())
        m_timer.start(int(std::max<qint64>(1, qint64((it->timeMs - posMs) * m_timeScale))));
}

// Provider that usually has this artist's lyrics, or "".
QString LyricsController::favouriteFor(const Track &t)
{
    const auto cands = Text::candidates(t);
    return cands.isEmpty() ? QString() : m_store.favourite(Text::norm(cands.first().artist));
}

// A clean synced answer: remember which provider delivered it for this artist.
void LyricsController::noteWin(const Track &t, const LyricsResult &r)
{
    if (r.synced.isEmpty() || r.provider.isEmpty() || Text::incompleteLrc(r.synced))
        return;
    const auto cands = Text::candidates(t);
    if (!cands.isEmpty())
        m_store.addWin(Text::norm(cands.first().artist), r.provider);
}

// Dominant colour of the cover: 24x24 thumbnail, hue buckets weighted by saturation, the winner's
// average brightened to a readable tone. Grey covers (no clear hue) give no accent.
static QColor dominant(const QImage &src)
{
    const QImage img = src.scaled(24, 24, Qt::IgnoreAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_RGB32);
    double w[12] = {}, r[12] = {}, g[12] = {}, b[12] = {};
    for (int y = 0; y < img.height(); ++y)
        for (int x = 0; x < img.width(); ++x) {
            const QColor c = img.pixelColor(x, y);
            const double wt = c.hsvSaturationF() * c.valueF();
            if (wt < 0.05 || c.hsvHue() < 0)
                continue;
            const int k = c.hsvHue() / 30 % 12;
            w[k] += wt; r[k] += wt * c.redF(); g[k] += wt * c.greenF(); b[k] += wt * c.blueF();
        }
    int best = 0;
    for (int k = 1; k < 12; ++k)
        if (w[k] > w[best])
            best = k;
    if (w[best] < 1.5)
        return {};
    QColor c = QColor::fromRgbF(r[best] / w[best], g[best] / w[best], b[best] / w[best]);
    float h, s, l;
    c.getHslF(&h, &s, &l);
    return QColor::fromHslF(h, std::max(s, 0.45f), std::clamp(l, 0.62f, 0.8f));
}

void LyricsController::updateArt(const QString &url)
{
    if (url == m_artUrl)
        return;
    m_artUrl = url;
    auto set = [this](const QColor &c) {
        if (c != m_accent) {
            m_accent = c;
            emit accentChanged();
        }
    };
    if (url.isEmpty()) {
        set({});
        return;
    }
    if (url.startsWith(QLatin1String("file:"))) {
        set(dominant(QImage(QUrl(url).toLocalFile())));
        return;
    }
    QNetworkReply *rep = m_artNam.get(QNetworkRequest(QUrl(url)));
    rep->setProperty("url", url);
    connect(rep, &QNetworkReply::finished, this, [this, rep, set, url] {
        rep->deleteLater();
        if (url != m_artUrl) // another song started meanwhile
            return;
        QImage img;
        if (rep->error() == QNetworkReply::NoError)
            img.loadFromData(rep->readAll());
        set(img.isNull() ? QColor() : dominant(img));
    });
}

qint64 LyricsController::positionMs(const MprisPlayer *p) const
{
    return qint64(p->positionUs() / 1000 / m_timeScale) + m_offsetMs + m_trackOffsetMs + m_leadMs;
}

// Milliseconds into the current line (for the word highlight).
int LyricsController::linePosMs() const
{
    const MprisPlayer *p = m_watcher.active();
    if (!p || m_index < 0 || m_index >= m_lrc.size())
        return 0;
    return int((positionMs(p) - m_lrc[m_index].timeMs) * m_timeScale);
}

// Word timing -> per source line a piecewise-linear "fraction of the line sung" curve [[ms, 0..1], ...].
// A yrc line belongs to the lyric line starting within 600 ms of it.
void LyricsController::parseWords(const QString &json)
{
    m_srcWords.clear();
    if (json.isEmpty() || m_srcLrc.isEmpty())
        return;
    const QJsonArray lines = QJsonDocument::fromJson(json.toUtf8()).array();
    QVector<qint64> starts;
    for (const auto &l : lines)
        starts << l.toArray().at(0).toInteger();
    m_srcWords.resize(m_srcLrc.size());
    for (qsizetype i = 0; i < m_srcLrc.size(); ++i) {
        const auto it = std::lower_bound(starts.cbegin(), starts.cend(), m_srcLrc[i].timeMs - 600);
        if (it == starts.cend() || *it > m_srcLrc[i].timeMs + 600)
            continue;
        const QJsonArray words = lines[int(it - starts.cbegin())].toArray().at(1).toArray();
        QString sung;
        for (const auto &w : words)
            sung += w.toArray().at(0).toString();
        // another version of the song may be timed differently: only trust words of the same line
        if (Text::similarityRaw(sung, m_srcLrc[i].text) < 0.7)
            continue;
        int total = 0;
        for (const auto &w : words)
            total += int(w.toArray().at(0).toString().size());
        if (total == 0)
            continue;
        QVariantList pts{QVariantList{0, 0.0}};
        int cum = 0;
        for (const auto &w : words) {
            const QJsonArray a = w.toArray();
            const int off = int(a.at(1).toInteger()), dur = int(a.at(2).toInteger());
            pts << QVariantList{off, double(cum) / total};
            cum += int(a.at(0).toString().size());
            pts << QVariantList{off + std::max(dur, 1), double(cum) / total};
        }
        m_srcWords[i] = pts;
    }
}

QVariantList LyricsController::karaoke() const
{
    if (m_index < 0 || m_index >= m_entrySrc.size())
        return {};
    const int src = m_entrySrc[m_index];
    return src >= 0 && src < m_srcWords.size() ? m_srcWords[src] : QVariantList();
}

// The listener runs only when asked for, something is playing and the widget is on screen.
void LyricsController::updateAudio()
{
    const MprisPlayer *p = m_watcher.active();
    const bool want = m_audioListen && (m_audioSync || m_audioTempo || m_beatPulse) && p && p->playing()
                      && !m_suspended && !m_idle;
    if (want)
        m_audio.start();
    else
        m_audio.stop();
    if (want && m_audioSync)
        m_audioSyncTimer.start();
    else
        m_audioSyncTimer.stop();
    emit bpmChanged();
}

// Every few seconds while a song plays: does the voice start where the timestamps say? Only a
// confident, sizeable disagreement is acted on, and never on a song the user has nudged by hand.
void LyricsController::checkAudioSync()
{
    if (!m_synced || m_autoSynced || m_suspended || m_key.isEmpty() || m_store.hasOffset(m_key))
        return;
    QVector<qint64> stamps;
    for (const LyricLine &l : std::as_const(m_srcLrc))
        if (!l.text.isEmpty())
            stamps << qint64(l.timeMs * m_timeScale);
    const auto e = m_audio.estimateOffset(stamps);
    if (qEnvironmentVariableIsSet("LYRICS_DEBUG"))
        qWarning() << "audio sync" << e.ok << e.offsetMs << e.confidence << e.lines;
    if (!e.ok)
        return;
    m_autoSynced = true;
    m_trackOffsetMs = e.offsetMs;
    m_store.setOffset(m_key, m_trackOffsetMs, m_provider); // remembered; also teaches the provider bias
    emit offsetMsChanged();
    resync();
}

void LyricsController::startLookup()
{
    m_requestId = m_fetcher.lookup(m_track);
}

// Japanese song without a provider romanization: fetch the human-made readings (UtaTen) and
// romanize from those, which gets unusual readings right (飛翔 sung "habata"). Asynchronous: the
// lyrics are already on screen, romanized by the local converter, and improve a moment later.
void LyricsController::maybeFetchReading(const StoredLyrics &s)
{
    if (!m_synced || !s.roman.isEmpty() || m_readingKey == m_key || m_srcText.isEmpty())
        return;
    bool kana = false;
    for (const QString &l : std::as_const(m_srcText))
        for (const QChar ch : l)
            kana |= (ch.unicode() >= 0x3041 && ch.unicode() <= 0x30FF);
    if (!kana)
        return;
    m_readingKey = m_key;
    const QString key = m_key;
    m_readingFetcher.fetch(m_title, m_artist, m_srcText, [this, key](const QStringList &r) {
        if (key != m_key || r.isEmpty())
            return;
        m_readingLines = r;
        romanizeKanji();
    });
}

// Keep the romanization made from readings: later plays get it from the cache like a provider's.
void LyricsController::persistRoman()
{
    auto cur = m_store.get(m_key);
    if (!cur)
        return;
    QString lrc;
    for (qsizetype i = 0; i < m_srcLrc.size() && i < m_srcRoman.size(); ++i) {
        if (m_srcRoman[i].isEmpty())
            continue;
        const qint64 ms = m_srcLrc[i].timeMs;
        lrc += QStringLiteral("[%1:%2.%3]%4\n").arg(ms / 60000, 2, 10, QLatin1Char('0'))
                   .arg(ms / 1000 % 60, 2, 10, QLatin1Char('0')).arg(ms % 1000 / 10, 2, 10, QLatin1Char('0'))
                   .arg(m_srcRoman[i]);
    }
    cur->roman = lrc;
    m_store.put(m_key, *cur);
}
