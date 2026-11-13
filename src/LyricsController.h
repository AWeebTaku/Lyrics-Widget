#pragma once
#include <QColor>
#include <QNetworkAccessManager>
#include <QFileSystemWatcher>
#include <QObject>
#include <QVariantList>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <QVector>
#include <QtQml/qqmlregistration.h>

#include "LrcParser.h"
#include "LyricsFetcher.h"
#include "LyricsStore.h"
#include "PlayerWatcher.h"
#include "ReadingFetcher.h"
#include "BrowserQueue.h"
#include "SpotifyApp.h"

// Glue between the player, the lyrics providers and the QML UI.
class LyricsController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool idle READ idle NOTIFY idleChanged)
    // false = lyrics switched off: no lookups, no look-ahead, nothing shown (the player is still followed)
    Q_PROPERTY(bool lyricsEnabled READ lyricsEnabled WRITE setLyricsEnabled NOTIFY lyricsEnabledChanged)
    // karaoke effect on: fetch word-timed lyrics too (only then is anything extra requested)
    Q_PROPERTY(bool karaoke READ karaoke WRITE setKaraoke NOTIFY karaokeChanged)
    Q_PROPERTY(QString title READ title NOTIFY trackInfoChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY trackInfoChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QStringList lines READ lines NOTIFY linesChanged)
    Q_PROPERTY(QStringList roman READ roman NOTIFY linesChanged) // parallel to lines, "" = none
    Q_PROPERTY(bool synced READ synced NOTIFY linesChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    // ms the current line stays on screen (min of the gaps before and after it). The line animation
    // scales to this so fast and slow songs both look right.
    Q_PROPERTY(int lineGapMs READ lineGapMs NOTIFY currentIndexChanged)
    // the current line has been sung and a long instrumental break follows: the UI fades it out
    Q_PROPERTY(bool lineHidden READ lineHidden NOTIFY lineHiddenChanged)
    Q_PROPERTY(int offsetMs READ offsetMs WRITE setOffsetMs NOTIFY offsetMsChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    // true = a full screen window covers the widget: do no work at all (timers, lookups, prefetch)
    Q_PROPERTY(bool suspended READ suspended WRITE setSuspended NOTIFY suspendedChanged)
    // How many upcoming Spotify queue tracks to fetch lyrics for ahead of time (0 = off, max 5)
    Q_PROPERTY(int prefetchCount READ prefetchCount WRITE setPrefetchCount NOTIFY prefetchCountChanged)
    Q_PROPERTY(bool spotifyAppQueue READ spotifyAppQueue WRITE setSpotifyAppQueue NOTIFY prefetchCountChanged)
    Q_PROPERTY(int spotifyDebugPort READ spotifyDebugPort WRITE setSpotifyDebugPort NOTIFY prefetchCountChanged)
    Q_PROPERTY(bool anyPlayer READ anyPlayer WRITE setAnyPlayer NOTIFY prefetchCountChanged)
    Q_PROPERTY(QString allowedSites READ allowedSites WRITE setAllowedSites NOTIFY prefetchCountChanged)
    Q_PROPERTY(bool browserQueue READ browserQueue WRITE setBrowserQueue NOTIFY prefetchCountChanged)
    Q_PROPERTY(int browserQueuePort READ browserQueuePort WRITE setBrowserQueuePort NOTIFY prefetchCountChanged)
    Q_PROPERTY(int trackOffsetMs READ trackOffsetMs NOTIFY offsetMsChanged) // this song's nudge
    // Matched version is this many seconds shorter(-)/longer(+) than the playing one; 0 = same
    // the synced lyrics skip a long stretch (missing verse): lines can't follow the song there
    // colours of the album art, light enough to read on a dark background; accent = the main one
    // (invalid when unknown), palette = up to four distinct ones
    Q_PROPERTY(QColor accent READ accent NOTIFY accentChanged)
    Q_PROPERTY(QVariantList palette READ palette NOTIFY accentChanged)
    Q_PROPERTY(bool incomplete READ incomplete NOTIFY linesChanged)
    // lines put back from the plain text with estimated times (a verse the synced copy skipped)
    Q_PROPERTY(int estimatedLines READ estimatedLines NOTIFY linesChanged)
    Q_PROPERTY(int gapSec READ gapSec NOTIFY linesChanged)

public:
    explicit LyricsController(QObject *parent = nullptr);
    bool idle() const { return m_idle; }
    bool lyricsEnabled() const { return m_lyricsEnabled; }
    void setLyricsEnabled(bool on);

    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString status() const { return m_status; }
    QStringList lines() const { return m_lines; }
    QStringList roman() const { return m_roman; }
    bool synced() const { return m_synced; }
    int currentIndex() const { return m_index; }
    bool karaoke() const { return m_karaoke; }
    void setKaraoke(bool on);
    int lineGapMs() const { return m_lineGapMs; }
    bool lineHidden() const { return m_lineHidden; }
    int offsetMs() const { return m_offsetMs; }
    void setOffsetMs(int ms);
    bool suspended() const { return m_suspended; }
    void setSuspended(bool on);
    bool playing() const { const auto *p = m_watcher.active(); return p && p->playing(); }
    bool anyPlayer() const { return m_anyPlayer; }
    void setAnyPlayer(bool on) { m_anyPlayer = on; m_watcher.setAnyPlayer(on); emit prefetchCountChanged(); }
    QString allowedSites() const { return m_sites; }
    void setAllowedSites(const QString &s) { m_sites = s; m_watcher.setSites(s.split(QLatin1Char(','), Qt::SkipEmptyParts)); emit prefetchCountChanged(); }
    int prefetchCount() const { return m_prefetchCount; }
    void setPrefetchCount(int n);
    bool spotifyAppQueue() const { return m_spotify.appQueue(); }
    int spotifyDebugPort() const { return m_spotify.debugPort(); }
    void setSpotifyAppQueue(bool on) { m_spotify.setAppQueue(on); emit prefetchCountChanged(); schedulePrefetch(); }
    void setSpotifyDebugPort(int p) { m_spotify.setDebugPort(p); emit prefetchCountChanged(); }
    bool browserQueue() const { return m_browserOn; }
    int browserQueuePort() const { return m_browserPort; }
    void setBrowserQueue(bool on) { m_browserOn = on; m_browser.configure(on, m_browserPort); emit prefetchCountChanged(); }
    void setBrowserQueuePort(int p) { m_browserPort = p; m_browser.configure(m_browserOn, p); emit prefetchCountChanged(); }
    int trackOffsetMs() const { return m_trackOffsetMs; }
    bool incomplete() const { return m_synced && m_filled == 0 && Text::incompleteLrc(m_syncedRaw); }
    QColor accent() const { return m_palette.isEmpty() ? QColor() : m_palette.first(); }
    QVariantList palette() const { QVariantList l; for (const QColor &c : m_palette) l << c; return l; }
    int estimatedLines() const { return m_filled; }
    int gapSec() const { return m_gapSec; }
    Q_INVOKABLE void nudge(int deltaMs); // saved per track; 0 resets
    // karaoke: where the player is in the current line, how long the line lasts, and the saved word times (may be empty)
    Q_INVOKABLE double lineElapsedMs() const; // -1 = no current line
    Q_INVOKABLE int lineDurMs() const;
    Q_INVOKABLE QVariantList lineWords() const;
    // Look for other lyrics for this song: the next best from the services, saved to the library. Wraps around.
    Q_INVOKABLE void refreshLyrics();

signals:
    void trackInfoChanged();
    void statusChanged();
    void linesChanged();
    void currentIndexChanged();
    void offsetMsChanged();
    void idleChanged();
    void playingChanged();
    void suspendedChanged();
    void accentChanged();
    void lyricsEnabledChanged();
    void lineHiddenChanged();
    void karaokeChanged();
    void prefetchCountChanged();

private:
    friend struct LayersTest; // tests/layers.cpp
    void onTrackChanged();
    void onResult(quint64 id, const LyricsResult &r, bool final);
    void apply(const StoredLyrics &s);
    void resync();
    void setStatus(const QString &s);
    void setIndex(int i);
    void setLineHidden(bool on);
    qint64 breakStartMs(int i) const;
    void clearLyrics();
    void schedulePrefetch();
    void prefetchNext();
    void romanizeKanji(bool force = false);
    void updateArt(const QString &url, int tries = 0);
    void startLookup();
    void watchDb();
    void checkLibrary();
    void fetchAltTitles(const QString &videoId, std::function<void(const QStringList &)> done);
    void beginLookup();
    QString m_host;
    QHash<QString, QStringList> m_altTitles; // YouTube Music video id -> its other names
    void fetchVideoTitle(const QString &videoId, std::function<void(const QString &)> done);
    void maybeFetchExtras(const StoredLyrics &s);
    bool isBannerLine(const QString &line) const;
    void maybeFetchReading(const StoredLyrics &s);
    void persistRoman();
    qint64 positionMs(const MprisPlayer *p) const;
    QString favouriteFor(const Track &t);
    void noteWin(const Track &t, const LyricsResult &r);
    void layer();

    PlayerWatcher m_watcher;
    LyricsStore m_store;
    QStringList m_skip;        // sources already shown for this song (see refreshLyrics)
    QString m_shown;           // source id of the lyrics on screen
    bool m_refreshing = false, m_libEdited = false, m_libIgnored = false;
    StoredLyrics m_applied;    // what is on screen, to put back when refreshing finds nothing
    void restoreAfterRefresh(const QString &note);
    LyricsFetcher m_fetcher;
    bool m_idle = true;
    bool m_lyricsEnabled = true;

    QString m_title, m_artist, m_status, m_key;
    QStringList m_lines, m_roman;
    bool m_karaoke = false;
    QHash<QString, QVariantList> m_words; // saved karaoke word times by line text (library)
    QVector<LyricLine> m_lrc;     // timeline actually shown (layered lines merged)
    QVector<LyricLine> m_srcLrc;  // one entry per lyric line as provided
    QStringList m_srcText, m_srcRoman;
    QString m_romanSig;        // the lines m_romanDone belongs to
    QStringList m_romanDone;   // the helper's romanization per source line (empty = not done yet)
    QList<bool> m_localRoman; // line i was romanized locally, not by the provider
    QString m_syncedRaw;
    int m_filled = 0;
    QString m_provider;
    bool m_metaSettled = false; // see onTrackChanged: the short wait for a song's artist is over
    qint64 m_libraryStamp = 0;      // 'updated' of the library entry in use, 0 = none
    QFileSystemWatcher m_dbWatch;   // the settings page edits the library: notice it without a restart
    QTimer m_dbDebounce;
    ReadingFetcher m_readingFetcher;
    LyricsFetcher m_extras;  // separate from m_fetcher: a new lookup there would cancel this
    quint64 m_extrasId = 0;
    QString m_extrasKey;
    QStringList m_readingLines; // UtaTen readings per source line ("漢字(かな)"), empty = none
    QString m_readingKey;       // song the reading was requested for
    QVector<int> m_entrySrc;          // shown entry -> source line, -1 when layered
    QNetworkAccessManager m_artNam;
    QString m_artUrl;
    QHash<QString, QString> m_videoTitles; // YouTube video id -> its title
    QList<QColor> m_palette;
    double m_timeScale = 1; // playing length / matched length, only for sped-up / slowed uploads
    bool m_synced = false;
    int m_index = -1;
    int m_lineGapMs = 2000;
    bool m_lineHidden = false;
    int m_offsetMs = 0;
    bool m_suspended = false;
    quint64 m_requestId = 0;
    QTimer m_timer;
    QProcess m_kakasi;
    quint64 m_applyGen = 0;
    int m_retries = 0;
    // prefetch of upcoming queue tracks (Spotify app, YouTube Music extension)
    SpotifyApp m_spotify;
    BrowserQueue m_browser;
    bool m_browserOn = false;
    int m_browserPort = 8899;
    LyricsFetcher m_pre;
    QTimer m_preTimer, m_preWatch;
    QList<Track> m_preQueue;
    Track m_preQueueCur;
    quint64 m_preId = 0;
    QString m_preKey;
    bool m_anyPlayer = false;
    QString m_sites;
    int m_prefetchCount = 3;
    int m_trackOffsetMs = 0;
    int m_gapSec = 0;
    Track m_track;
};
