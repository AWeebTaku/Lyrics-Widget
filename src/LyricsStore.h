#pragma once
#include <QSqlDatabase>
#include <QList>
#include <QString>
#include <optional>

struct StoredLyrics {
    bool found = false;        // false = negative cache entry ("no lyrics exist")
    bool instrumental = false;
    QString synced;            // raw LRC text
    QString plain;
    QString roman;             // provider romanization (LRC), may be empty
    double srcDur = 0;         // length of the version the lyrics were timed against
    QString provider;          // who supplied it
    bool extras = false;       // the one-off background NetEase lookup (romanization) has been made
    QString sourceId;          // which provider result it is ("lrclib:12"), to skip it when asking for other lyrics
    QString words;             // karaoke word times (JSON, WordTiming.h); "" = not asked yet, "{}" = asked, none
};

// A song in the user's own lyrics library: lyrics they fetched, edited or retimed. These win over the cache
// and survive rebuilds. The metadata (title, artist, length, language, source) is what a shared catalogue
// would need to find a song again.
struct LibraryEntry {
    QString key;       // see Keys::songKey
    QString title, artist, album;
    int durationSec = 0;
    QString lang;      // "" = unknown
    QString synced;    // LRC; empty when only plain text exists
    QString plain;
    QString roman;
    QString source;    // "edited", or the provider the text came from
    QString words;     // karaoke: JSON {"line text": [start ms of each word, from the line's start]}
    QString origTitle, origArtist; // set when the song is a cover or version: the original's name
    qint64 updated = 0; // ms since epoch
};

// Tiny SQLite cache. A cache hit makes a repeat song show lyrics instantly,
// with zero network traffic.
class LyricsStore
{
public:
    LyricsStore();
    ~LyricsStore();
    std::optional<StoredLyrics> get(const QString &key);
    void put(const QString &key, const StoredLyrics &value);
    int offset(const QString &key);                 // per-track sync nudge, ms
    bool hasOffset(const QString &key);
    void setOffset(const QString &key, int ms, const QString &provider = {});
    // What the user's nudges say about a provider's timing: median once there are enough samples that agree
    int learnedOffset(const QString &provider);
    // Which provider keeps winning for an artist (empty until there is a clear favourite)
    void addWin(const QString &artist, const QString &provider);
    QString favourite(const QString &artist);

    // the lyrics library
    std::optional<LibraryEntry> library(const QString &key);
    qint64 libraryStamp(const QString &key); // 0 when there is no entry
    void putLibrary(const LibraryEntry &e);
    void removeLibrary(const QString &key);

private:
    QString m_conn;
    QSqlDatabase m_db;
};
