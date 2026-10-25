#pragma once
#include <QColor>
#include <QNetworkAccessManager>
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
#include "AudioListener.h"
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
    Q_PROPERTY(QString title READ title NOTIFY trackInfoChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY trackInfoChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QStringList lines READ lines NOTIFY linesChanged)
    Q_PROPERTY(QStringList roman READ roman NOTIFY linesChanged) // parallel to lines, "" = none
    Q_PROPERTY(bool hasRoman READ hasRoman NOTIFY linesChanged)
    Q_PROPERTY(bool synced READ synced NOTIFY linesChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    // ms the current line stays on screen (min of the gaps before and after it). The line animation
    // scales to this so fast and slow songs both look right.
    Q_PROPERTY(int lineGapMs READ lineGapMs NOTIFY currentIndexChanged)
    Q_PROPERTY(int offsetMs READ offsetMs WRITE setOffsetMs NOTIFY offsetMsChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    // true = a full screen window covers the widget: do no work at all (timers, lookups, prefetch)
    Q_PROPERTY(bool suspended READ suspended WRITE setSuspended NOTIFY suspendedChanged)
    // Show each line this many ms before its timestamp (so a fade-in finishes when it is sung)
    Q_PROPERTY(int leadMs READ leadMs WRITE setLeadMs NOTIFY offsetMsChanged)
    // How many upcoming Spotify queue tracks to fetch lyrics for ahead of time (0 = off, max 5)
    Q_PROPERTY(int prefetchCount READ prefetchCount WRITE setPrefetchCount NOTIFY prefetchCountChanged)
    Q_PROPERTY(bool spotifyAppQueue READ spotifyAppQueue WRITE setSpotifyAppQueue NOTIFY prefetchCountChanged)
    Q_PROPERTY(int spotifyDebugPort READ spotifyDebugPort WRITE setSpotifyDebugPort NOTIFY prefetchCountChanged)
    Q_PROPERTY(bool browserQueue READ browserQueue WRITE setBrowserQueue NOTIFY prefetchCountChanged)
    Q_PROPERTY(int browserQueuePort READ browserQueuePort WRITE setBrowserQueuePort NOTIFY prefetchCountChanged)
    Q_PROPERTY(int trackOffsetMs READ trackOffsetMs NOTIFY offsetMsChanged) // this song's nudge
    // Matched version is this many seconds shorter(-)/longer(+) than the playing one; 0 = same
    // the synced lyrics skip a long stretch (missing verse): lines can't follow the song there
    // dominant colour of the album art, light enough to read on a dark background; invalid when unknown
    // word timing of the current line: [[msIntoLine, fractionSung], ...] or empty
    Q_PROPERTY(QVariantList karaoke READ karaoke NOTIFY currentIndexChanged)
    // Listening to the system audio (opt-in): timing check, tempo, beat
    Q_PROPERTY(bool audioListen READ audioListen WRITE setAudioListen NOTIFY audioChanged)
    Q_PROPERTY(bool audioSync READ audioSync WRITE setAudioSync NOTIFY audioChanged)
    Q_PROPERTY(bool audioTempo READ audioTempo WRITE setAudioTempo NOTIFY audioChanged)
    Q_PROPERTY(bool beatPulse READ beatPulse WRITE setBeatPulse NOTIFY audioChanged)
    Q_PROPERTY(double bpm READ bpm NOTIFY bpmChanged)
    Q_PROPERTY(bool autoSynced READ autoSynced NOTIFY offsetMsChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY accentChanged)
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
    bool hasRoman() const { return m_hasRoman; }
    bool synced() const { return m_synced; }
    int currentIndex() const { return m_index; }
    int lineGapMs() const { return m_lineGapMs; }
    int offsetMs() const { return m_offsetMs; }
    void setOffsetMs(int ms);
    bool suspended() const { return m_suspended; }
    void setSuspended(bool on);
    int leadMs() const { return m_leadMs; }
    void setLeadMs(int ms) { if (ms != m_leadMs) { m_leadMs = ms; emit offsetMsChanged(); resync(); } }
    bool playing() const { const auto *p = m_watcher.active(); return p && p->playing(); }
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
    QVariantList karaoke() const;
    Q_INVOKABLE int linePosMs() const;
    bool audioListen() const { return m_audioListen; }
    bool audioSync() const { return m_audioSync; }
    bool audioTempo() const { return m_audioTempo; }
    bool beatPulse() const { return m_beatPulse; }
    void setAudioListen(bool on) { m_audioListen = on; emit audioChanged(); updateAudio(); }
    void setAudioSync(bool on) { m_audioSync = on; emit audioChanged(); updateAudio(); }
    void setAudioTempo(bool on) { m_audioTempo = on; emit audioChanged(); updateAudio(); }
    void setBeatPulse(bool on) { m_beatPulse = on; emit audioChanged(); updateAudio(); }
    double bpm() const { return m_audio.running() ? m_audio.bpm() : 0; }
    bool autoSynced() const { return m_autoSynced; }
    QColor accent() const { return m_accent; }
    int estimatedLines() const { return m_filled; }
    int gapSec() const { return m_gapSec; }
    Q_INVOKABLE void nudge(int deltaMs); // saved per track; 0 resets

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
    void audioChanged();
    void bpmChanged();
    void beat();
    void prefetchCountChanged();

private:
    friend struct LayersTest; // tests/layers.cpp
    void onTrackChanged();
    void onResult(quint64 id, const LyricsResult &r, bool final);
    void apply(const StoredLyrics &s);
    void resync();
    void setStatus(const QString &s);
    void setIndex(int i);
    void clearLyrics();
    void schedulePrefetch();
    void prefetchNext();
    void romanizeKanji();
    void updateArt(const QString &url);
    void startLookup();
    void maybeFetchExtras(const StoredLyrics &s);
    bool isBannerLine(const QString &line) const;
    void maybeFetchReading(const StoredLyrics &s);
    void persistRoman();
    void updateAudio();
    void checkAudioSync();
    void parseWords(const QString &json);
    qint64 positionMs(const MprisPlayer *p) const;
    QString favouriteFor(const Track &t);
    void noteWin(const Track &t, const LyricsResult &r);
    void layer();

    PlayerWatcher m_watcher;
    LyricsStore m_store;
    LyricsFetcher m_fetcher;
    bool m_idle = true;
    bool m_lyricsEnabled = true;

    QString m_title, m_artist, m_status, m_key;
    QStringList m_lines, m_roman;
    QVector<LyricLine> m_lrc;     // timeline actually shown (layered lines merged)
    QVector<LyricLine> m_srcLrc;  // one entry per lyric line as provided
    QStringList m_srcText, m_srcRoman;
    QList<bool> m_localRoman; // line i was romanized locally, not by the provider
    QString m_syncedRaw;
    int m_filled = 0;
    QString m_provider;
    ReadingFetcher m_readingFetcher;
    LyricsFetcher m_extras;  // separate from m_fetcher: a new lookup there would cancel this
    quint64 m_extrasId = 0;
    QString m_extrasKey;
    QStringList m_readingLines; // UtaTen readings per source line ("漢字(かな)"), empty = none
    QString m_readingKey;       // song the reading was requested for
    AudioListener m_audio;
    QTimer m_audioSyncTimer;
    bool m_audioListen = false, m_audioSync = false, m_audioTempo = true, m_beatPulse = false;
    bool m_autoSynced = false;
    QVector<int> m_entrySrc;          // shown entry -> source line, -1 when layered
    QVector<QVariantList> m_srcWords; // per source line, word timing curve
    QNetworkAccessManager m_artNam;
    QString m_artUrl;
    QColor m_accent;
    double m_timeScale = 1; // playing length / matched length, only for sped-up / slowed uploads
    bool m_synced = false;
    bool m_hasRoman = false;
    int m_index = -1;
    int m_lineGapMs = 2000;
    int m_offsetMs = 0;
    int m_leadMs = 0;
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
    int m_prefetchCount = 3;
    int m_trackOffsetMs = 0;
    int m_gapSec = 0;
    Track m_track;
};
