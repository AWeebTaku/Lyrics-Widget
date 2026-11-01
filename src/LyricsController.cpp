#include "LyricsController.h"

#include "GapFill.h"
#include "Keys.h"
#include "Palette.h"
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
#include <limits>

namespace {
constexpr qint64 kBreakHoldMs = 3500; // a finished line stays this long, for words held for effect


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

    m_dbDebounce.setSingleShot(true);
    m_dbDebounce.setInterval(400);
    connect(&m_dbDebounce, &QTimer::timeout, this, &LyricsController::checkLibrary);
    connect(&m_dbWatch, &QFileSystemWatcher::fileChanged, this, [this] {
        watchDb(); // the -wal file comes and goes
        m_dbDebounce.start();
    });
    watchDb();

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
            s.plain = r.plain; s.roman = r.roman; s.srcDur = r.srcDur; s.provider = r.provider;
            m_store.put(m_preKey, s);
            noteWin(m_preQueueCur, r);
        }
        QTimer::singleShot(5000, this, [this] { prefetchNext(); }); // gentle: one song per 5 s
    });
    connect(&m_fetcher, &LyricsFetcher::result, this, &LyricsController::onResult);
    connect(&m_extras, &LyricsFetcher::result, this, [this](quint64 id, const LyricsResult &r, bool final) {
        if (id != m_extrasId || !final)
            return;
        m_extrasId = 0;
        auto cur = m_store.get(m_extrasKey);
        if (!cur || m_extrasKey != m_key)
            return;
        cur->extras = true; // asked: do not ask again for this song, whatever NetEase answered
        if (cur->roman.isEmpty() && !r.roman.isEmpty()) {
            // NetEase's romanization is only used when it lines up with the lyrics being shown
            const auto shown = Lrc::parse(cur->synced);
            int hit = 0, total = 0;
            RomanAlign::align(shown, Lrc::parse(r.roman), &hit);
            for (const LyricLine &l : shown)
                total += !l.text.isEmpty();
            if (total > 0 && hit >= 0.85 * total)
                cur->roman = r.roman;
        }
        m_store.put(m_extrasKey, *cur);
        apply(*cur);
    });

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
    // Back on screen: if the song is the same as before, keep what was found (or not found) and just catch up
    // to the right line; a different song is looked up as usual.
    onTrackChanged();
    resync();
}

void LyricsController::setLyricsEnabled(bool on)
{
    if (on == m_lyricsEnabled)
        return;
    m_lyricsEnabled = on;
    emit lyricsEnabledChanged();
    if (!on) {
        m_requestId = 0;
        m_preQueue.clear();
        m_preId = 0;
        m_preTimer.stop();
        m_preWatch.stop();
        clearLyrics();
        setStatus(QString());
        return;
    }
    m_key.clear(); // look at what is playing now
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
    if (m_suspended || !m_lyricsEnabled)
        return;
    if (m_prefetchCount > 0 && (m_spotify.appQueue() || m_browser.enabled()))
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
        m_spotify.fetchLyrics(cur.id, [this, cur, key](bool ok, const SpotifyApp::AppLyrics &l) {
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
    m_synced = false;
    m_index = -1;
    setLineHidden(false);
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
    t.id = Keys::trackId(p->url());
    t.durationSec = int(p->lengthUs() / 1'000'000);

    // Browsers announce a song in pieces (title first, artist and address a moment later): a lookup on the
    // first piece would be thrown away. Give the rest a moment to arrive.
    if (t.artist.isEmpty() && t.id.isEmpty() && !m_metaSettled && Keys::songKey(t) != m_key) {
        QTimer::singleShot(150, this, [this] {
            m_metaSettled = true;
            onTrackChanged();
            m_metaSettled = false;
        });
        return;
    }
    const QString key = Keys::songKey(t);
    if (key == m_key)
        return; // same song (e.g. metadata refresh): keep what we have
    m_preQueue.clear(); // the user moved on: drop any look-ahead in progress
    m_preId = 0;
    m_preTimer.stop();
    m_key = key;
    m_track = t;
    m_skip.clear();
    m_shown.clear();
    m_refreshing = m_libEdited = m_libIgnored = false;
    m_readingLines.clear();
    m_trackOffsetMs = m_store.offset(key); // a learned provider delay may replace this in apply()
    m_gapSec = 0;
    emit offsetMsChanged();
    m_retries = 0;

    const auto cands = Text::candidates(t);
    m_title = cands.isEmpty() ? t.title : cands.first().title;
    m_artist = cands.isEmpty() ? t.artist : cands.first().artist;
    emit trackInfoChanged();
    clearLyrics();
    if (!m_lyricsEnabled) {
        m_requestId = 0;
        setStatus(QString());
        return;
    }

    // The user's own library wins over everything: lyrics they saved, edited or retimed
    m_libraryStamp = 0;
    if (const auto lib = m_store.library(key)) {
        m_libraryStamp = lib->updated;
        if (lib->source == QLatin1String("none") && lib->synced.isEmpty() && lib->plain.isEmpty()) {
            m_libIgnored = true; // the user turned lyrics off for this song (library page)
            m_requestId = 0;
            setStatus(QStringLiteral("Lyrics are turned off for this song"));
            return;
        }
        StoredLyrics s;
        s.found = true;
        s.synced = lib->synced;
        s.plain = lib->plain;
        s.roman = lib->roman;
        s.srcDur = lib->durationSec;
        s.provider = QStringLiteral("library");
        m_shown = lib->source;
        m_libEdited = lib->source == QLatin1String("edited");
        m_requestId = 0;
        apply(s);
        schedulePrefetch();
        return;
    }
    if (Text::notASong(t, p->url())) {
        m_requestId = 0;
        setStatus(QStringLiteral("Not a song — no lyrics to look up"));
        return;
    }
    if (const auto cached = m_store.get(key)) {
        m_requestId = 0; // a late answer for the previous song must not land on this one
        m_shown = cached->sourceId;
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
        m_spotify.fetchLyrics(t.id, [this, k](bool ok, const SpotifyApp::AppLyrics &l) {
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
            s.sourceId = m_shown = QStringLiteral("spotify:app");
            m_store.put(k, s);
            apply(s);
            schedulePrefetch();
        });
        return;
    }
    m_host = QUrl(p->url()).host();
    // YouTube Music shows a song under its English name while the catalogues know it by its original one:
    // ask YouTube Music for the other names first
    if (m_host == QLatin1String("music.youtube.com") && t.id.size() == 11) {
        const QString k = m_key;
        fetchAltTitles(t.id, [this, k](const QStringList &alt) {
            if (k != m_key)
                return;
            m_track.alt = alt;
            beginLookup();
        });
        return;
    }
    beginLookup();
}

void LyricsController::beginLookup()
{
    // The player's text can hide which language version this is ("0 (zero)" for the English single).
    // The title in the track itself says, and so does YouTube's own title for the video.
    m_track.lang = Text::languageHint(m_track.title);
    if (m_track.lang.isEmpty() && m_host.contains(QLatin1String("youtube")) && !m_track.id.isEmpty()) {
        const QString k = m_key;
        fetchVideoTitle(m_track.id, [this, k](const QString &videoTitle) {
            if (k != m_key)
                return;
            m_track.lang = Text::languageHint(videoTitle);
            startLookup();
        });
        return;
    }
    startLookup();
}

void LyricsController::onResult(quint64 id, const LyricsResult &r, bool final)
{
    if (id != m_requestId)
        return; // a newer track superseded this request

    if (m_refreshing && !r.networkError && r.synced.isEmpty()) {
        if (final) // nothing else out there: the lyrics from before come back, the next press starts over
            restoreAfterRefresh(QStringLiteral("No other lyrics found"));
        return;
    }
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
    if (r.networkError) {
        if (m_refreshing && !retry)
            restoreAfterRefresh(QStringLiteral("Couldn't reach the lyrics service"));
        return;
    }
    StoredLyrics s;
    s.found = r.found;
    s.instrumental = r.instrumental;
    s.synced = r.synced;
    s.plain = r.plain;
    s.roman = r.roman;
    s.srcDur = r.srcDur;
    s.provider = r.provider;
    s.sourceId = r.sourceId;
    if (final && !retry && m_refreshing) { // chosen by the user: kept in the library, which wins from now on
        LibraryEntry e;
        e.key = m_key;
        e.title = m_track.title;
        e.artist = m_track.artist;
        e.album = m_track.album;
        e.durationSec = m_track.durationSec;
        e.lang = m_track.lang;
        e.synced = r.synced;
        e.plain = r.plain;
        e.roman = r.roman;
        e.source = r.sourceId;
        m_store.putLibrary(e);
        m_libraryStamp = m_store.libraryStamp(m_key); // no reload: it is on screen already
        m_refreshing = false;
    }
    if (r.found)
        m_shown = r.sourceId;
    if (final && !retry && !m_libraryStamp) {
        m_store.put(m_key, s);
        noteWin(m_track, r);
        schedulePrefetch();
    }
    apply(s);
}

void LyricsController::apply(const StoredLyrics &s)
{
    m_applied = s;
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
        // "Artist - Title" banners some providers put first, at 0:00: not part of the song
        for (int i = 0; i < 3 && !m_srcLrc.isEmpty() && m_srcLrc.first().timeMs <= 2500
                        && isBannerLine(m_srcLrc.first().text); ++i)
            m_srcLrc.removeFirst();
        if (Text::incompleteLrc(s.synced))
            m_filled = GapFill::fill(m_srcLrc, s.plain);
        for (const LyricLine &l : std::as_const(m_srcLrc))
            m_srcText << l.text;
        m_synced = !m_srcLrc.isEmpty();
    }
    if (!m_synced && !s.instrumental && !s.plain.isEmpty()) {
        m_srcLrc.clear();
        m_srcText = s.plain.split(QLatin1Char('\n'));
        for (int i = 0; i < 3 && !m_srcText.isEmpty() && isBannerLine(m_srcText.first()); ++i)
            m_srcText.removeFirst();
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
    // One lookup produces several answers (first one, then better ones). The helper's accurate romanization of
    // these very lines is kept across them, so the text never flips back to the quick local version.
    const QString sig = m_srcText.join(QLatin1Char('\n'));
    if (sig != m_romanSig) {
        m_romanSig = sig;
        m_romanDone = QStringList(m_srcText.size());
    }
    for (qsizetype i = 0; i < m_srcText.size(); ++i)
        if (m_localRoman[i] && !m_romanDone[i].isEmpty())
            m_srcRoman[i] = m_romanDone[i];

    // Matched version's length vs the playing one: a gap hints at an intro/outro (music video,
    // remix) that shifts the timing. Small gaps are normal encoder differences.
    m_gapSec = 0;
    if (s.srcDur > 0 && m_track.durationSec > 0) {
        const int gap = m_track.durationSec - int(std::lround(s.srcDur));
        m_gapSec = std::abs(gap) >= 4 ? gap : 0;
    }

    // Sped-up / slowed version of a song: stretch the timestamps to the playing length
    m_timeScale = 1;
    if (s.srcDur > 0 && m_track.durationSec > 0 && s.provider != QLatin1String("library")
        && Text::tempoVariant(m_track.title) != 0) {
        const double k = m_track.durationSec / s.srcDur;
        if (k > 0.5 && k < 1.6 && std::abs(k - 1) > 0.03) {
            m_timeScale = k;
            m_gapSec = 0; // the length difference is explained
        }
    }

    layer();
    m_index = -1;
    emit linesChanged();
    emit currentIndexChanged();
    resync();
    romanizeKanji();
    maybeFetchReading(s);
    maybeFetchExtras(s);
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
}

// Kanji lines have no local rule-based romanization. If `kakasi` is installed, convert them in
// one async batch (a few ms) and fill the gaps. Dictionary-based, not context-aware: readings of
// some words will be off, which is why provider romanization always wins.
void LyricsController::romanizeKanji(bool force)
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
        if (m_srcText[i].isEmpty() || (mecab ? !m_localRoman[i] : !m_srcRoman[i].isEmpty())
            || (!force && i < m_romanDone.size() && !m_romanDone[i].isEmpty()))
            continue; // not ours to romanize, or done already
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
            if (!mecab || !r.isEmpty()) {
                m_srcRoman[todo[k]] = r;
                if (todo[k] < m_romanDone.size())
                    m_romanDone[todo[k]] = r;
            }
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
    // while synced lyrics are on screen, keep an eye on the real position (seeks the player does not announce)
    m_watcher.setWatchPosition(m_synced && !m_suspended && m_lyricsEnabled);
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

    // a finished line is hidden during a long instrumental break
    const qint64 hideAt = idx >= 0 ? breakStartMs(idx) : -1;
    setLineHidden(hideAt >= 0 && posMs >= hideAt);

    if (!p->playing())
        return;
    qint64 wake = it != m_lrc.cend() ? it->timeMs : -1; // the next line, or the moment the break starts
    if (hideAt >= 0 && posMs < hideAt && (wake < 0 || hideAt < wake))
        wake = hideAt;
    if (wake >= 0)
        m_timer.start(int(std::max<qint64>(1, qint64((wake - posMs) * m_timeScale))));
}

void LyricsController::setLineHidden(bool on)
{
    if (on == m_lineHidden)
        return;
    m_lineHidden = on;
    emit lineHiddenChanged();
}

// When line i has been sung, if a break long enough to notice follows; -1 when there is none. How long a
// line takes to sing is guessed from its length, plus a hold so a word stretched for effect is still on
// screen. The last line of the song counts too (an instrumental outro).
qint64 LyricsController::breakStartMs(int i) const
{
    if (i < 0 || i >= m_lrc.size() || i >= m_lines.size() || m_lines[i].isEmpty())
        return -1; // empty lines are the break markers themselves
    const qint64 sung = std::clamp<qint64>(1500 + m_lines[i].size() * 110, 3000, 9000);
    const qint64 end = m_lrc[i].timeMs + sung + kBreakHoldMs;
    const qint64 next = i + 1 < m_lrc.size() ? m_lrc[i + 1].timeMs : std::numeric_limits<qint64>::max();
    return next - end > 4000 ? end : -1;
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

void LyricsController::updateArt(const QString &url)
{
    if (url == m_artUrl)
        return;
    m_artUrl = url;
    auto set = [this](const QList<QColor> &p) {
        if (p != m_palette) {
            m_palette = p;
            emit accentChanged();
        }
    };
    if (url.isEmpty()) {
        set({});
        return;
    }
    if (url.startsWith(QLatin1String("file:"))) {
        set(Palette::of(QImage(QUrl(url).toLocalFile())));
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
        set(img.isNull() ? QList<QColor>() : Palette::of(img));
    });
}

qint64 LyricsController::positionMs(const MprisPlayer *p) const
{
    return qint64(p->positionUs() / 1000 / m_timeScale) + m_offsetMs + m_trackOffsetMs;
}

void LyricsController::refreshLyrics()
{
    if (m_key.isEmpty() || !m_lyricsEnabled || m_suspended || m_refreshing)
        return;
    if (m_libIgnored) {
        setStatus(QStringLiteral("Lyrics are turned off for this song: use Get lyrics in the library to look for them"));
        return;
    }
    if (m_libEdited) {
        setStatus(QStringLiteral("You edited these lyrics: remove them in the library to look again"));
        return;
    }
    if (!m_shown.isEmpty() && !m_skip.contains(m_shown))
        m_skip << m_shown;
    m_track.skip = m_skip;
    m_track.onlySynced = true;
    m_refreshing = true;
    m_retries = 0;
    clearLyrics(); // the old lyrics make way for the search
    setStatus(QStringLiteral("Finding lyrics…"));
    m_requestId = m_fetcher.lookup(m_track);
}

void LyricsController::restoreAfterRefresh(const QString &note)
{
    m_refreshing = false;
    m_skip.clear();
    m_track.skip.clear();
    m_track.onlySynced = false;
    m_requestId = 0;
    apply(m_applied);
    setStatus(note);
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
        romanizeKanji(true); // the readings change what the helper gives
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

// A line that only says the song's title (or "artist - title"), in any script: a banner, not a lyric.
bool LyricsController::isBannerLine(const QString &line) const
{
    const QString t = line.trimmed();
    if (Text::norm(t).isEmpty())
        return false;
    static const QRegularExpression sep(QStringLiteral(R"(\s+[-–—－:：|｜]\s+)"));
    const QStringList parts = t.split(sep, Qt::SkipEmptyParts);
    auto isTitle = [this](const QString &p) {
        return Text::similarity(p, m_title) >= 0.85 || Text::similarity(p, m_track.title) >= 0.85;
    };
    auto isArtist = [this](const QString &p) {
        return !m_artist.isEmpty() && (Text::similarity(p, m_artist) >= 0.6 || Text::similarity(p, m_track.artist) >= 0.6);
    };
    if (parts.size() == 1) {
        // alone on a line it must be the title itself (a lyric that merely contains the title is a lyric)
        static const QRegularExpression extra(QStringLiteral(R"(\s*[\(（\[].*[\)）\]]\s*)"));
        QString bare = parts[0];
        bare.remove(extra);
        const QString n = Text::norm(bare);
        return !n.isEmpty() && (n == Text::norm(m_title) || n == Text::norm(m_track.title)
                                || (!m_artist.isEmpty() && n == Text::norm(m_artist)));
    }
    bool title = false, artist = false;
    for (const QString &p : parts) {
        title |= isTitle(p);
        artist |= isArtist(p);
    }
    return title && artist;
}

// Lyrics from the Spotify app come without romanization. Ask NetEase for it in the background, once per song.
void LyricsController::maybeFetchExtras(const StoredLyrics &s)
{
    if (!m_synced || s.provider != QLatin1String("spotify") || s.extras || m_extrasKey == m_key)
        return;
    m_extrasKey = m_key;
    m_extrasId = m_extras.lookupExtras(m_track);
}

// YouTube's title for a video (public oEmbed, nothing but the id is sent), cached for the session.
// The song's names as YouTube Music lists them in Japanese (title and album); empty on any failure.
void LyricsController::fetchAltTitles(const QString &videoId, std::function<void(const QStringList &)> done)
{
    if (m_altTitles.contains(videoId)) {
        done(m_altTitles.value(videoId));
        return;
    }
    QNetworkRequest req(QUrl(QStringLiteral("https://music.youtube.com/youtubei/v1/next?prettyPrint=false")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Origin", "https://music.youtube.com");
    req.setTransferTimeout(3000);
    const QJsonObject ctx{{QStringLiteral("client"), QJsonObject{{QStringLiteral("clientName"), QStringLiteral("WEB_REMIX")},
                                                                  {QStringLiteral("clientVersion"), QStringLiteral("1.20240101.01.00")},
                                                                  {QStringLiteral("hl"), QStringLiteral("ja")}}}};
    QNetworkReply *rep = m_artNam.post(req, QJsonDocument(QJsonObject{{QStringLiteral("context"), ctx}, {QStringLiteral("videoId"), videoId}}).toJson(QJsonDocument::Compact));
    connect(rep, &QNetworkReply::finished, this, [this, rep, videoId, done] {
        rep->deleteLater();
        QStringList alt;
        if (rep->error() == QNetworkReply::NoError) {
            const QJsonObject o = QJsonDocument::fromJson(rep->readAll()).object();
            // the playing video's entry in the queue panel: its title in the account language
            const QJsonArray tabs = o.value(QStringLiteral("contents")).toObject()
                .value(QStringLiteral("singleColumnMusicWatchNextResultsRenderer")).toObject()
                .value(QStringLiteral("tabbedRenderer")).toObject()
                .value(QStringLiteral("watchNextTabbedResultsRenderer")).toObject().value(QStringLiteral("tabs")).toArray();
            for (const QJsonValue &tab : tabs) {
                const QJsonArray items = tab.toObject().value(QStringLiteral("tabRenderer")).toObject().value(QStringLiteral("content")).toObject()
                    .value(QStringLiteral("musicQueueRenderer")).toObject().value(QStringLiteral("content")).toObject()
                    .value(QStringLiteral("playlistPanelRenderer")).toObject().value(QStringLiteral("contents")).toArray();
                for (const QJsonValue &it : items) {
                    const QJsonObject r = it.toObject().value(QStringLiteral("playlistPanelVideoRenderer")).toObject();
                    if (r.value(QStringLiteral("videoId")).toString() != videoId)
                        continue;
                    const QString title = r.value(QStringLiteral("title")).toObject().value(QStringLiteral("runs")).toArray()
                                              .first().toObject().value(QStringLiteral("text")).toString().trimmed();
                    if (!title.isEmpty())
                        alt << title;
                }
            }
            const QString album = o.value(QStringLiteral("playerOverlays")).toObject().value(QStringLiteral("playerOverlayRenderer")).toObject()
                .value(QStringLiteral("browserMediaSession")).toObject().value(QStringLiteral("browserMediaSessionRenderer")).toObject()
                .value(QStringLiteral("album")).toObject().value(QStringLiteral("runs")).toArray().first().toObject()
                .value(QStringLiteral("text")).toString().trimmed();
            if (!album.isEmpty())
                alt << album;
            if (m_altTitles.size() > 64)
                m_altTitles.clear();
            m_altTitles.insert(videoId, alt);
        }
        done(alt);
    });
}

void LyricsController::fetchVideoTitle(const QString &videoId, std::function<void(const QString &)> done)
{
    if (m_videoTitles.contains(videoId)) {
        done(m_videoTitles.value(videoId));
        return;
    }
    QUrl u(QStringLiteral("https://www.youtube.com/oembed"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("url"), QStringLiteral("https://www.youtube.com/watch?v=") + videoId);
    q.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    u.setQuery(q);
    QNetworkRequest req(u);
    req.setTransferTimeout(3000);
    QNetworkReply *rep = m_artNam.get(req);
    connect(rep, &QNetworkReply::finished, this, [this, rep, videoId, done] {
        rep->deleteLater();
        const QString title = rep->error() == QNetworkReply::NoError
                                  ? QJsonDocument::fromJson(rep->readAll()).object().value(QStringLiteral("title")).toString()
                                  : QString();
        if (!title.isEmpty())
            m_videoTitles.insert(videoId, title);
        done(title); // empty on failure: the lookup goes ahead without it
    });
}

void LyricsController::watchDb()
{
    const QString db = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/lyrics.db");
    for (const QString &f : {db, db + QStringLiteral("-wal")})
        if (QFile::exists(f) && !m_dbWatch.files().contains(f))
            m_dbWatch.addPath(f);
}

// The settings page saved or removed this song's library entry: show the change at once.
void LyricsController::checkLibrary()
{
    if (m_key.isEmpty() || !m_lyricsEnabled || m_suspended)
        return;
    if (m_store.libraryStamp(m_key) != m_libraryStamp) {
        m_key.clear();
        onTrackChanged();
    }
}
