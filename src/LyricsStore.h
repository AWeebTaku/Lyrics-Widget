#pragma once
#include <QSqlDatabase>
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
    QString words;             // word timing (JSON), may be empty
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

private:
    QString m_conn;
    QSqlDatabase m_db;
};
