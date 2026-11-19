#pragma once
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMap>
#include <QRegularExpression>
#include <QString>
#include <QStringDecoder>
#include <QUrl>
#include <QVector>
#include <algorithm>

#include "LrcParser.h"

// Lyrics and chapters that sit on the user's own disk: a ".lrc" beside the song (or in a lyrics folder), lyrics
// stored inside the file (ID3 tags of MP3, Vorbis comments of FLAC), and chapter lists (".chapters", ".cue").
// Nothing here opens a network address or writes anything.
namespace LocalFiles {

inline QString pathFromUrl(const QString &url)
{
    const QUrl u(url);
    return u.isLocalFile() ? u.toLocalFile() : QString();
}

inline QString readText(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 2 * 1024 * 1024)
        return {};
    const QByteArray data = f.readAll();
    QString s;
    if (data.startsWith("\xFF\xFE") || data.startsWith("\xFE\xFF"))
        s = QStringDecoder(QStringDecoder::Utf16)(data);
    else
        s = QString::fromUtf8(data);
    if (s.startsWith(QChar(0xFEFF)))
        s.remove(0, 1);
    return s;
}

// ---- lyric files
inline QString normName(QString s) { return s.toLower().remove(QRegularExpression(QStringLiteral(R"([^\p{L}\p{N}]+)"))); }

// the lyric file of a song: next to it (same name, or "name.ext.lrc"), else in the lyrics folder by "Artist - Title" or "Title"
inline QString findLrc(const QString &songPath, const QString &folder, const QString &title, const QString &artist)
{
    if (!songPath.isEmpty()) {
        const QFileInfo fi(songPath);
        for (const QString &c : {fi.path() + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(".lrc"), songPath + QStringLiteral(".lrc")})
            if (QFileInfo::exists(c))
                return c;
    }
    if (!folder.isEmpty() && !title.isEmpty()) {
        const QStringList want{normName(artist + title), normName(title)};
        const auto entries = QDir(folder).entryInfoList({QStringLiteral("*.lrc")}, QDir::Files);
        for (const QString &w : want)
            for (const QFileInfo &e : entries)
                if (!w.isEmpty() && normName(e.completeBaseName()) == w)
                    return e.filePath();
    }
    return {};
}

// "song.romaji.lrc" / "song.reading.lrc": a pronunciation for the lines, beside the song's lyric file
inline QString findReading(const QString &lrcPath)
{
    const QFileInfo fi(lrcPath);
    for (const char *kind : {"romaji", "reading", "romanized"}) {
        const QString c = fi.path() + QLatin1Char('/') + fi.completeBaseName() + QLatin1Char('.') + QLatin1String(kind) + QStringLiteral(".lrc");
        if (QFileInfo::exists(c))
            return c;
    }
    return {};
}

// ---- ID3v2 (MP3): USLT / ULT (plain lyrics) and SYLT / SLT (timed, turned into LRC)
namespace detail {
inline quint32 be32(const char *p) { return (quint32(quint8(p[0])) << 24) | (quint32(quint8(p[1])) << 16) | (quint32(quint8(p[2])) << 8) | quint8(p[3]); }
inline quint32 syncsafe(const char *p) { return (quint32(quint8(p[0])) << 21) | (quint32(quint8(p[1])) << 14) | (quint32(quint8(p[2])) << 7) | quint8(p[3]); }

// text in an ID3 encoding; returns the text and moves `pos` past its terminator
inline QString id3Text(const QByteArray &d, int enc, qsizetype &pos, bool terminated = true)
{
    const bool wide = enc == 1 || enc == 2;
    qsizetype end = pos;
    if (wide) {
        while (end + 1 < d.size() && !(d[end] == 0 && d[end + 1] == 0))
            end += 2;
    } else {
        while (end < d.size() && d[end] != 0)
            ++end;
    }
    if (end > d.size())
        end = d.size();
    const QByteArray raw = d.mid(pos, end - pos);
    pos = std::min<qsizetype>(d.size(), end + (terminated ? (wide ? 2 : 1) : 0));
    if (enc == 0)
        return QString::fromLatin1(raw);
    if (enc == 3)
        return QString::fromUtf8(raw);
    if (enc == 2)
        return QStringDecoder(QStringDecoder::Utf16BE)(raw);
    return QStringDecoder(QStringDecoder::Utf16)(raw);   // with a byte order mark
}

inline QString syltToLrc(const QByteArray &f)
{
    if (f.size() < 7 || quint8(f[4]) != 2)    // timestamp format 2 = milliseconds; frame counts are not handled
        return {};
    const int enc = quint8(f[0]);
    qsizetype pos = 6;
    id3Text(f, enc, pos);                    // the content descriptor
    QString lrc, line;
    qint64 lineAt = -1;
    auto flush = [&] { if (lineAt >= 0 && !line.trimmed().isEmpty()) lrc += Lrc::stamp(lineAt) + line.trimmed() + QLatin1Char('\n'); line.clear(); lineAt = -1; };
    while (pos < f.size()) {
        QString text = id3Text(f, enc, pos);
        if (pos + 4 > f.size())
            break;
        const qint64 ms = be32(f.constData() + pos);
        pos += 4;
        if (text.startsWith(QLatin1Char('\n')) || text.startsWith(QLatin1Char('\r'))) flush();
        if (lineAt < 0)
            lineAt = ms;
        line += text.remove(QLatin1Char('\n')).remove(QLatin1Char('\r'));
        if (text.isEmpty()) continue;
    }
    flush();
    return lrc;
}
} // namespace detail

inline QString id3Lyrics(const QByteArray &file)
{
    if (file.size() < 10 || !file.startsWith("ID3"))
        return {};
    const int ver = quint8(file[3]);
    const quint8 flags = quint8(file[5]);
    if (ver < 2 || ver > 4)
        return {};
    const qsizetype tagSize = detail::syncsafe(file.constData() + 6);
    QByteArray tag = file.mid(10, tagSize);
    if (flags & 0x80)                         // unsynchronisation: 0xFF 0x00 stands for 0xFF
        tag.replace(QByteArray("\xFF\x00", 2), QByteArray("\xFF", 1));
    qsizetype pos = 0;
    if ((flags & 0x40) && ver >= 3 && tag.size() >= 4)   // an extended header is skipped
        pos = ver == 4 ? detail::syncsafe(tag.constData()) : detail::be32(tag.constData()) + 4;
    const int idLen = ver == 2 ? 3 : 4, hdr = ver == 2 ? 6 : 10;
    QString plain, synced;
    while (pos + hdr <= tag.size()) {
        const QByteArray id = tag.mid(pos, idLen);
        if (id.at(0) == 0)
            break;
        qsizetype size = ver == 2 ? (quint32(quint8(tag[pos + 3])) << 16 | quint32(quint8(tag[pos + 4])) << 8 | quint8(tag[pos + 5]))
                         : ver == 4 ? detail::syncsafe(tag.constData() + pos + 4) : detail::be32(tag.constData() + pos + 4);
        const QByteArray data = tag.mid(pos + hdr, size);
        pos += hdr + size;
        if ((id == "USLT" || id == "ULT") && data.size() > 4 && plain.isEmpty()) {
            const int enc = quint8(data[0]);
            qsizetype p = 4;
            detail::id3Text(data, enc, p);    // descriptor
            plain = detail::id3Text(data, enc, p, false);
        } else if ((id == "SYLT" || id == "SLT") && synced.isEmpty()) {
            synced = detail::syltToLrc(data);
        }
    }
    return !synced.isEmpty() ? synced : plain;
}

// ---- FLAC: Vorbis comments LYRICS / UNSYNCEDLYRICS
inline QString flacLyrics(const QByteArray &file)
{
    if (!file.startsWith("fLaC"))
        return {};
    qsizetype pos = 4;
    while (pos + 4 <= file.size()) {
        const quint8 h = quint8(file[pos]);
        const qsizetype len = (quint32(quint8(file[pos + 1])) << 16) | (quint32(quint8(file[pos + 2])) << 8) | quint8(file[pos + 3]);
        if ((h & 0x7F) == 4) {
            const QByteArray b = file.mid(pos + 4, len);
            auto le32 = [&](qsizetype p) { return p + 4 <= b.size() ? quint32(quint8(b[p])) | (quint32(quint8(b[p + 1])) << 8) | (quint32(quint8(b[p + 2])) << 16) | (quint32(quint8(b[p + 3])) << 24) : 0u; };
            qsizetype p = 4 + le32(0);
            const quint32 n = le32(p);
            p += 4;
            for (quint32 i = 0; i < n && p + 4 <= b.size(); ++i) {
                const qsizetype l = le32(p);
                p += 4;
                const QString kv = QString::fromUtf8(b.mid(p, l));
                p += l;
                const qsizetype eq = kv.indexOf(QLatin1Char('='));
                const QString key = kv.left(eq).toUpper();
                if (eq > 0 && (key == QLatin1String("LYRICS") || key == QLatin1String("UNSYNCEDLYRICS") || key == QLatin1String("SYNCEDLYRICS")))
                    return kv.mid(eq + 1);
            }
        }
        if (h & 0x80)
            break;
        pos += 4 + len;
    }
    return {};
}

// lyrics stored inside a song file (MP3 or FLAC); "" when there are none or the format is not one of these
inline QString embeddedLyrics(const QString &songPath)
{
    QFile f(songPath);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    const QByteArray head = f.read(4);
    f.seek(0);
    if (head.startsWith("ID3")) {
        const QByteArray h = f.read(10);
        f.seek(0);
        const qsizetype size = h.size() == 10 ? detail::syncsafe(h.constData() + 6) + 10 : 0;
        return id3Lyrics(f.read(std::min<qsizetype>(size, 8 * 1024 * 1024)));
    }
    if (head.startsWith("fLaC"))
        return flacLyrics(f.read(8 * 1024 * 1024));
    return {};
}

// ---- chapters
struct Chapter { double start = 0; QString title; };

inline double clock(const QString &s)   // "00:01:23.500" or "1:23.5" or "83.5"
{
    const QStringList p = s.trimmed().split(QLatin1Char(':'));
    double sec = 0;
    for (const QString &x : p)
        sec = sec * 60 + x.toDouble();
    return sec;
}

inline QVector<Chapter> parseChapterText(const QString &text)
{
    static const QRegularExpression ogm(QStringLiteral(R"(^CHAPTER(\d+)(NAME)?=(.*)$)"), QRegularExpression::CaseInsensitiveOption);
    QMap<int, Chapter> byNumber;
    for (const QString &raw : text.split(QLatin1Char('\n'))) {
        const auto m = ogm.match(raw.trimmed());
        if (!m.hasMatch())
            continue;
        Chapter &c = byNumber[m.captured(1).toInt()];
        if (m.captured(2).isEmpty()) c.start = clock(m.captured(3)); else c.title = m.captured(3).trimmed();
    }
    QVector<Chapter> out;
    for (const Chapter &c : std::as_const(byNumber))
        out.push_back(c);
    return out;
}

inline QVector<Chapter> parseCue(const QString &text)
{
    static const QRegularExpression index(QStringLiteral(R"(^\s*INDEX\s+01\s+(\d+):(\d+):(\d+))"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression title(QStringLiteral(R"re(^\s*TITLE\s+"?([^"]*)"?\s*$)re"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression track(QStringLiteral(R"(^\s*TRACK\s+\d+)"), QRegularExpression::CaseInsensitiveOption);
    QVector<Chapter> out;
    QString pendingTitle;
    bool inTrack = false;
    for (const QString &raw : text.split(QLatin1Char('\n'))) {
        if (track.match(raw).hasMatch()) { inTrack = true; pendingTitle.clear(); continue; }
        if (!inTrack) continue;
        if (const auto t = title.match(raw); t.hasMatch()) pendingTitle = t.captured(1);
        if (const auto i = index.match(raw); i.hasMatch())
            out.push_back({i.captured(1).toInt() * 60.0 + i.captured(2).toInt() + i.captured(3).toInt() / 75.0, pendingTitle});
    }
    return out;
}

// chapters of a song file from a sidecar ".chapters" (OGM text) or ".cue"; sorted, no duplicates, at most 512
inline QVector<Chapter> chaptersFor(const QString &songPath, double durationSec = 0)
{
    if (songPath.isEmpty())
        return {};
    const QFileInfo fi(songPath);
    QVector<Chapter> v;
    const QString base = fi.path() + QLatin1Char('/') + fi.completeBaseName();
    if (QFileInfo::exists(base + QStringLiteral(".chapters")))
        v = parseChapterText(readText(base + QStringLiteral(".chapters")));
    if (v.isEmpty() && QFileInfo::exists(base + QStringLiteral(".cue")))
        v = parseCue(readText(base + QStringLiteral(".cue")));
    std::sort(v.begin(), v.end(), [](const Chapter &a, const Chapter &b) { return a.start < b.start; });
    QVector<Chapter> out;
    for (int i = 0; i < v.size() && out.size() < 512; ++i) {
        if (v[i].start < 0 || (durationSec > 0 && v[i].start >= durationSec) || (!out.isEmpty() && v[i].start == out.last().start))
            continue;
        if (v[i].title.isEmpty())
            v[i].title = QStringLiteral("Chapter %1").arg(out.size() + 1);
        out.push_back(v[i]);
    }
    return out;
}

} // namespace LocalFiles
