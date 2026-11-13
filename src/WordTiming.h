#pragma once
#include <QByteArray>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPair>
#include <QRegularExpression>
#include <QVector>
#include <cmath>

#include "LrcParser.h"
#include "QqDes.h"

// Word-timed lyrics, for the karaoke effect. Two providers publish them next to the line-timed ones:
//   NetEase "yrc":  [lineStartMs,durMs](wordStartMs,durMs,0)word(...)word     (word times are absolute)
//   Kugou   "krc":  [lineStartMs,durMs]<offsetMs,durMs,0>word<...>word        (offsets from the line start)
// What the widget keeps is JSON keyed by the line's text: {"line": [[startMs from line start, end char], ...]}
//   QQ      "qrc":  [lineStartMs,durMs]word(wordStartMs,durMs)word(...)      (the time follows its word; absolute)
// where "end char" is where that word ends in the line's text.
namespace WordTiming {

enum Format { Yrc, Krc, Qrc };

struct WordLine {
    qint64 start = 0;
    QVector<QPair<qint64, QString>> words; // offset from the line's start, text
};

inline QVector<WordLine> parse(const QString &text, Format format)
{
    static const QRegularExpression head(QStringLiteral(R"(^\[(\d+),\d+\])"));
    static const QRegularExpression yrcWord(QStringLiteral(R"(\((\d+),\d+,-?\d+\))"));
    static const QRegularExpression krcWord(QStringLiteral(R"(<(\d+),\d+,-?\d+>)"));
    static const QRegularExpression qrcWord(QStringLiteral(R"(\((\d+),\d+\))"));
    QVector<WordLine> out;
    for (const QString &raw : text.split(QLatin1Char('\n'))) {
        const QString row = raw.trimmed();
        const auto h = head.match(row);
        if (!h.hasMatch())
            continue;
        WordLine wl;
        wl.start = h.captured(1).toLongLong();
        QVector<QRegularExpressionMatch> ms;
        for (auto it = (format == Krc ? krcWord : format == Qrc ? qrcWord : yrcWord).globalMatch(row, h.capturedEnd()); it.hasNext();)
            ms.push_back(it.next());
        for (qsizetype k = 0; k < ms.size(); ++k) {
            // Yrc / Krc: the time comes first and the word follows it; Qrc: the word first, then its time
            const qsizetype from = format == Qrc ? (k ? ms[k - 1].capturedEnd() : h.capturedEnd()) : ms[k].capturedEnd();
            const qsizetype to = format == Qrc ? ms[k].capturedStart() : k + 1 < ms.size() ? ms[k + 1].capturedStart() : row.size();
            const qint64 t = ms[k].captured(1).toLongLong();
            wl.words.push_back({format == Krc ? t : t - wl.start, row.mid(from, to - from)});
        }
        if (!wl.words.isEmpty())
            out.push_back(wl);
    }
    return out;
}

// The word times of the lines that appear in `lrc` with the same words (spaces aside). Empty when none do.
inline QString toJson(const QString &lrc, const QVector<WordLine> &lines)
{
    const auto lrcLines = Lrc::parse(lrc);
    QJsonObject out;
    for (const WordLine &wl : lines) {
        const LyricLine *best = nullptr; // the line that starts at the same moment
        for (const LyricLine &l : lrcLines) {
            const qint64 d = std::abs(l.timeMs - wl.start);
            if (!l.text.isEmpty() && d <= 600 && (!best || d < std::abs(best->timeMs - wl.start)))
                best = &l;
        }
        if (!best || out.contains(best->text))
            continue;
        const QString &text = best->text;
        QString a, b;
        for (const auto &w : wl.words)
            for (const QChar c : w.second)
                if (!c.isSpace())
                    a += c;
        for (const QChar c : text)
            if (!c.isSpace())
                b += c;
        if (a != b)
            continue;
        QJsonArray arr;
        qsizetype pos = 0;
        for (const auto &w : wl.words) {
            int n = 0;
            for (const QChar c : w.second)
                n += !c.isSpace();
            if (n == 0)
                continue;
            for (; n > 0 && pos < text.size(); ++pos)
                n -= !text[pos].isSpace();
            arr.append(QJsonArray{double(w.first), double(pos)});
        }
        out.insert(text, arr);
    }
    return out.isEmpty() ? QString() : QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
}

// zlib data to bytes (qUncompress wants the unpacked size in front: only an upper bound is needed)
inline QByteArray inflate(const QByteArray &z)
{
    const quint32 expect = quint32(std::min<qsizetype>(z.size() * 30, 16 << 20));
    QByteArray framed;
    for (int s = 24; s >= 0; s -= 8)
        framed.append(char((expect >> s) & 0xff));
    return qUncompress(framed + z);
}

// Kugou's download answer: base64 of "krc1" + zlib data, every byte XORed with a fixed key.
inline QString krcText(const QByteArray &base64)
{
    static const unsigned char key[16] = {64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105};
    QByteArray raw = QByteArray::fromBase64(base64);
    if (raw.size() < 8)
        return {};
    raw.remove(0, 4);
    for (qsizetype i = 0; i < raw.size(); ++i)
        raw[i] = char(static_cast<unsigned char>(raw[i]) ^ key[i % 16]);
    return QString::fromUtf8(inflate(raw));
}

// QQ's answer: hex of the QRC cipher (QqDes.h) over zlib data over an XML wrapper whose LyricContent is the text
inline QString qrcText(const QByteArray &hex)
{
    const QString xml = QString::fromUtf8(inflate(QqDes::decrypt(QByteArray::fromHex(hex))));
    const QString open = QStringLiteral("LyricContent=\"");
    const qsizetype a = xml.indexOf(open);
    if (a < 0)
        return {};
    const qsizetype b = xml.indexOf(QStringLiteral("\"/>"), a);
    QString t = xml.mid(a + open.size(), b < 0 ? -1 : b - a - open.size());
    return t.replace(QStringLiteral("&quot;"), QStringLiteral("\"")).replace(QStringLiteral("&apos;"), QStringLiteral("'"))
        .replace(QStringLiteral("&lt;"), QStringLiteral("<")).replace(QStringLiteral("&gt;"), QStringLiteral(">"))
        .replace(QStringLiteral("&amp;"), QStringLiteral("&"));
}

} // namespace WordTiming
