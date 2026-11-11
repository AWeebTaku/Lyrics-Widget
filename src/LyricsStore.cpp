#include "LyricsStore.h"

#include "Text.h"

#include <QDateTime>
#include <algorithm>
#include <QDir>
#include <QSqlQuery>
#include <QStandardPaths>

namespace {
constexpr qint64 kNegativeTtlSecs = 24 * 3600; // retry "not found" after a day (catalogues grow)
}

LyricsStore::LyricsStore()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);

    m_conn = QStringLiteral("lyrics-cache-%1").arg(quintptr(this));
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_conn);
    m_db.setDatabaseName(dir + QStringLiteral("/lyrics.db"));
    if (!m_db.open())
        return;

    QSqlQuery q(m_db);
    q.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    q.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS lyrics_v6("
                          "key TEXT PRIMARY KEY, found INTEGER, instrumental INTEGER,"
                          "synced TEXT, plain TEXT, roman TEXT, srcdur REAL, fetched INTEGER, provider TEXT, extras INTEGER, source_id TEXT)"));
    // the cache is only a convenience: forget what has not been fetched for 90 days (the library and the
    // offsets are the user's own and are never pruned)
    q.prepare(QStringLiteral("DELETE FROM lyrics_v6 WHERE fetched < ?"));
    q.addBindValue(QDateTime::currentSecsSinceEpoch() - 90 * 24 * 3600);
    q.exec();
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS offsets(key TEXT PRIMARY KEY, ms INTEGER)"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS nudges(key TEXT PRIMARY KEY, provider TEXT, ms INTEGER)"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS library(key TEXT PRIMARY KEY, title TEXT, artist TEXT, album TEXT,"
                          "duration INTEGER, lang TEXT, synced TEXT, plain TEXT, roman TEXT, source TEXT, updated INTEGER)"));
    // older databases lack the original's name (fails harmlessly when the column exists)
    q.exec(QStringLiteral("ALTER TABLE library ADD COLUMN orig_title TEXT"));
    q.exec(QStringLiteral("ALTER TABLE library ADD COLUMN orig_artist TEXT"));
    q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS wins(artist TEXT, provider TEXT, n INTEGER, PRIMARY KEY(artist, provider))"));
}

LyricsStore::~LyricsStore()
{
    m_db.close();
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(m_conn);
}

std::optional<StoredLyrics> LyricsStore::get(const QString &key)
{
    if (!m_db.isOpen())
        return std::nullopt;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT found, instrumental, synced, plain, roman, srcdur, fetched, provider, extras, source_id FROM lyrics_v6 WHERE key=?"));
    q.addBindValue(key);
    if (!q.exec() || !q.next())
        return std::nullopt;

    StoredLyrics s;
    s.found = q.value(0).toBool();
    s.instrumental = q.value(1).toBool();
    s.synced = q.value(2).toString();
    s.plain = q.value(3).toString();
    s.roman = q.value(4).toString();
    s.srcDur = q.value(5).toDouble();
    s.provider = q.value(7).toString();
    s.extras = q.value(8).toBool();
    s.sourceId = q.value(9).toString();
    const qint64 age = QDateTime::currentSecsSinceEpoch() - q.value(6).toLongLong();
    // "not found" and unsynced-only answers may improve later (catalogues grow, providers flake)
    if ((!s.found || (s.synced.isEmpty() && !s.instrumental)) && age > kNegativeTtlSecs)
        return std::nullopt;
    // a CJK song saved without any provider romanization: look again after an hour, it is
    // usually a provider that was having a bad moment
    if (!s.synced.isEmpty() && s.roman.isEmpty() && Text::isCjk(s.synced) && s.provider != QLatin1String("netease")
        && age > 3600)
        return std::nullopt;
    return s;
}

void LyricsStore::put(const QString &key, const StoredLyrics &v)
{
    if (!m_db.isOpen())
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO lyrics_v6"
                             "(key, found, instrumental, synced, plain, roman, srcdur, fetched, provider, extras, source_id)"
                             " VALUES(?,?,?,?,?,?,?,?,?,?,?)"));
    q.addBindValue(key);
    q.addBindValue(v.found ? 1 : 0);
    q.addBindValue(v.instrumental ? 1 : 0);
    q.addBindValue(v.synced);
    q.addBindValue(v.plain);
    q.addBindValue(v.roman);
    q.addBindValue(v.srcDur);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.addBindValue(v.provider);
    q.addBindValue(v.extras ? 1 : 0);
    q.addBindValue(v.sourceId);
    q.exec();
}

int LyricsStore::offset(const QString &key)
{
    if (!m_db.isOpen())
        return 0;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT ms FROM offsets WHERE key=?"));
    q.addBindValue(key);
    return (q.exec() && q.next()) ? q.value(0).toInt() : 0;
}

bool LyricsStore::hasOffset(const QString &key)
{
    if (!m_db.isOpen())
        return false;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT 1 FROM offsets WHERE key=?"));
    q.addBindValue(key);
    return q.exec() && q.next();
}

void LyricsStore::setOffset(const QString &key, int ms, const QString &provider)
{
    if (!m_db.isOpen())
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO offsets(key, ms) VALUES(?,?)"));
    q.addBindValue(key);
    q.addBindValue(ms);
    q.exec();
    if (provider.isEmpty())
        return;
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO nudges(key, provider, ms) VALUES(?,?,?)"));
    q.addBindValue(key);
    q.addBindValue(provider);
    q.addBindValue(ms);
    q.exec();
}

int LyricsStore::learnedOffset(const QString &provider)
{
    if (!m_db.isOpen() || provider.isEmpty())
        return 0;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT ms FROM nudges WHERE provider=? AND ms<>0 ORDER BY ms"));
    q.addBindValue(provider);
    QList<int> v;
    if (q.exec())
        while (q.next())
            v << q.value(0).toInt();
    if (v.size() < 5)
        return 0;
    const int med = v[v.size() / 2];
    // a systematic delay means the nudges cluster around one value; a wide spread (-2 s, +1 s, +3 s) is noise
    const int near = int(std::count_if(v.cbegin(), v.cend(), [med](int x) { return std::abs(x - med) <= 500; }));
    if (near < 0.8 * v.size())
        return 0;
    return std::abs(med) >= 100 ? med : 0;
}

void LyricsStore::addWin(const QString &artist, const QString &provider)
{
    if (!m_db.isOpen() || artist.isEmpty() || provider.isEmpty())
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO wins(artist, provider, n) VALUES(?,?,1) "
                             "ON CONFLICT(artist, provider) DO UPDATE SET n=n+1"));
    q.addBindValue(artist);
    q.addBindValue(provider);
    q.exec();
}

QString LyricsStore::favourite(const QString &artist)
{
    if (!m_db.isOpen() || artist.isEmpty())
        return {};
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT provider, n FROM wins WHERE artist=? ORDER BY n DESC"));
    q.addBindValue(artist);
    if (!q.exec())
        return {};
    int top = 0, total = 0;
    QString who;
    while (q.next()) {
        if (!top) { top = q.value(1).toInt(); who = q.value(0).toString(); }
        total += q.value(1).toInt();
    }
    return (top >= 3 && top >= 0.7 * total) ? who : QString();
}

namespace {
LibraryEntry readEntry(QSqlQuery &q)
{
    LibraryEntry e;
    e.key = q.value(0).toString();
    e.title = q.value(1).toString();
    e.artist = q.value(2).toString();
    e.album = q.value(3).toString();
    e.durationSec = q.value(4).toInt();
    e.lang = q.value(5).toString();
    e.synced = q.value(6).toString();
    e.plain = q.value(7).toString();
    e.roman = q.value(8).toString();
    e.source = q.value(9).toString();
    e.updated = q.value(10).toLongLong();
    e.origTitle = q.value(11).toString();
    e.origArtist = q.value(12).toString();
    return e;
}
constexpr const char *kLibraryCols = "key, title, artist, album, duration, lang, synced, plain, roman, source, updated, orig_title, orig_artist";
}

std::optional<LibraryEntry> LyricsStore::library(const QString &key)
{
    if (!m_db.isOpen())
        return std::nullopt;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT %1 FROM library WHERE key=?").arg(QLatin1String(kLibraryCols)));
    q.addBindValue(key);
    if (!q.exec() || !q.next())
        return std::nullopt;
    return readEntry(q);
}

qint64 LyricsStore::libraryStamp(const QString &key)
{
    if (!m_db.isOpen())
        return 0;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT updated FROM library WHERE key=?"));
    q.addBindValue(key);
    return (q.exec() && q.next()) ? q.value(0).toLongLong() : 0;
}

void LyricsStore::putLibrary(const LibraryEntry &e)
{
    if (!m_db.isOpen())
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT OR REPLACE INTO library(%1) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)").arg(QLatin1String(kLibraryCols)));
    q.addBindValue(e.key);
    q.addBindValue(e.title);
    q.addBindValue(e.artist);
    q.addBindValue(e.album);
    q.addBindValue(e.durationSec);
    q.addBindValue(e.lang);
    q.addBindValue(e.synced);
    q.addBindValue(e.plain);
    q.addBindValue(e.roman);
    q.addBindValue(e.source);
    q.addBindValue(QDateTime::currentMSecsSinceEpoch());
    q.addBindValue(e.origTitle);
    q.addBindValue(e.origArtist);
    q.exec();
}

void LyricsStore::removeLibrary(const QString &key)
{
    if (!m_db.isOpen())
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM library WHERE key=?"));
    q.addBindValue(key);
    q.exec();
}
