#pragma once
#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include "LyricsFetcher.h"
#include "LyricsStore.h"
#include "PlayerWatcher.h"

// Behind the "Lyrics library" settings page: gets, edits, retimes and saves the lyrics of the song that is
// playing. A saved song goes into the library table of lyrics.db, which wins over every provider and over
// the cache, and survives rebuilds. The widget notices the change by itself.
class LyricsLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString title READ title NOTIFY trackChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY trackChanged)
    Q_PROPERTY(int durationSec READ durationSec NOTIFY trackChanged)
    Q_PROPERTY(bool hasSong READ hasSong NOTIFY trackChanged)
    Q_PROPERTY(bool saved READ saved NOTIFY savedChanged) // the library has this song
    Q_PROPERTY(bool ignored READ ignored NOTIFY savedChanged) // ...as "no lyrics": the widget does not look it up
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY statusChanged)
    // the typed title and artist name the ORIGINAL of this song (a cover, remix or vocaloid version)
    Q_PROPERTY(bool coverMode READ coverMode WRITE setCoverMode NOTIFY coverModeChanged)

public:
    bool coverMode() const { return m_cover; }
    void setCoverMode(bool on) { if (on != m_cover) { m_cover = on; emit coverModeChanged(); } }
    // the original's name saved with a cover: shown again when the song comes back
    Q_PROPERTY(QString origTitle READ origTitle NOTIFY trackChanged)
    Q_PROPERTY(QString origArtist READ origArtist NOTIFY trackChanged)
    QString origTitle() const { return m_origTitle; }
    QString origArtist() const { return m_origArtist; }
    explicit LyricsLibrary(QObject *parent = nullptr);

    QString title() const { return m_track.title; }
    QString artist() const { return m_track.artist; }
    int durationSec() const { return m_track.durationSec; }
    bool hasSong() const { return !m_track.title.isEmpty(); }
    bool saved() const { return m_saved; }
    bool ignored() const { return m_ignored; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE QString load();                                           // the saved lyrics, else the cached ones
    Q_INVOKABLE void search(const QString &title, const QString &artist); // answer arrives as found()
    Q_INVOKABLE void startOver() { m_skip.clear(); m_query.clear(); } // the next search begins with the best result
    Q_INVOKABLE void ignoreSong(); // no lyrics for this song (a cover or edit that matches nothing); saving lyrics later replaces it
    Q_INVOKABLE bool save(const QString &text, const QString &title, const QString &artist, const QString &origTitle = {}, const QString &origArtist = {});
    Q_INVOKABLE void remove();
    // t' = t * percent/100 + shiftMs, for every timestamp of the text
    Q_INVOKABLE QString retime(const QString &text, double percent, int shiftMs) const;
    // moves the timestamps of lines firstLine..lastLine (0-based; lastLine < 0 = to the end) by shiftMs
    Q_INVOKABLE QString shiftLines(const QString &text, int firstLine, int lastLine, int shiftMs) const;
    // linear: the first timestamp lands at firstSec, the last at lastSec
    Q_INVOKABLE QString fit(const QString &text, double firstSec, double lastSec) const;
    // the time of one line (0-based), for setting a single line's time by hand
    Q_INVOKABLE double lineTime(const QString &text, int line) const; // seconds, -1 = the line has no time
    Q_INVOKABLE QString setLineTime(const QString &text, int line, double sec) const; // replaces / adds the line's first stamp
    Q_INVOKABLE double playheadSec() const; // where the playing song is, -1 when nothing plays
    Q_INVOKABLE QVariantMap timing(const QString &text) const; // {first, last, lines} in seconds

signals:
    void coverModeChanged();
    void trackChanged();
    void savedChanged();
    void statusChanged();
    void found(const QString &text, const QString &provider);

private:
    void onTrack();
    void setStatus(const QString &s, bool busy = false);

    PlayerWatcher m_watcher;
    LyricsStore m_store;
    LyricsFetcher m_fetcher;
    Track m_track;
    QString m_key, m_status, m_origTitle, m_origArtist;
    bool m_saved = false, m_ignored = false, m_busy = false;
    quint64 m_searchId = 0;
    QStringList m_skip; // results of this search already shown: each press of Get lyrics shows the next one
    QString m_query;
    bool m_cover = false;
    bool m_stretchToSong = false; // the searched title is an edit: stretch the result to the playing length
};
