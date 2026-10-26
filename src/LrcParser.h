#pragma once
#include <QRegularExpression>
#include <QString>
#include <QVector>
#include <algorithm>

struct LyricLine {
    qint64 timeMs = 0;
    QString text;
};

namespace Lrc {

// Parses "[mm:ss.xx] text" lines (multiple timestamps per line supported).
// Metadata tags such as [ar:...] / [ti:...] are ignored.
inline QVector<LyricLine> parse(const QString &lrc)
{
    static const QRegularExpression tagRe(
        QStringLiteral(R"(\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\])"));

    QVector<LyricLine> out;
    const QStringList rows = lrc.split(QLatin1Char('\n'));
    for (const QString &raw : rows) {
        const QString row = raw.trimmed();
        if (!row.startsWith(QLatin1Char('[')))
            continue;

        QVector<qint64> times;
        qsizetype end = 0;
        auto it = tagRe.globalMatch(row);
        while (it.hasNext()) {
            const auto m = it.next();
            if (m.capturedStart() != end)
                break;
            const qint64 min = m.captured(1).toLongLong();
            const qint64 sec = m.captured(2).toLongLong();
            const QString frac = m.captured(3);
            qint64 ms = 0;
            if (frac.size() == 1)      ms = frac.toInt() * 100;
            else if (frac.size() == 2) ms = frac.toInt() * 10;
            else if (frac.size() == 3) ms = frac.toInt();
            times.push_back(min * 60000 + sec * 1000 + ms);
            end = m.capturedEnd();
        }
        if (times.isEmpty())
            continue;

        const QString text = row.mid(end).trimmed();
        for (qint64 t : std::as_const(times))
            out.push_back({t, text});
    }
    std::stable_sort(out.begin(), out.end(),
                     [](const LyricLine &a, const LyricLine &b) { return a.timeMs < b.timeMs; });
    return out;
}

// "[mm:ss.xx]"
inline QString stamp(qint64 ms)
{
    ms = std::max<qint64>(0, ms);
    return QStringLiteral("[%1:%2.%3]").arg(ms / 60000, 2, 10, QLatin1Char('0'))
        .arg(ms / 1000 % 60, 2, 10, QLatin1Char('0')).arg(ms % 1000 / 10, 2, 10, QLatin1Char('0'));
}

// Rewrites every timestamp of an LRC text with fn(ms); every other character is kept as written.
template <typename Fn>
inline QString mapStamps(const QString &lrc, Fn fn)
{
    static const QRegularExpression re(QStringLiteral(R"(\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\])"));
    QString out;
    qsizetype last = 0;
    for (auto it = re.globalMatch(lrc); it.hasNext();) {
        const auto m = it.next();
        out += lrc.mid(last, m.capturedStart() - last);
        const QString frac = m.captured(3);
        qint64 ms = m.captured(1).toLongLong() * 60000 + m.captured(2).toLongLong() * 1000;
        ms += frac.size() == 1 ? frac.toInt() * 100 : frac.size() == 2 ? frac.toInt() * 10 : frac.toInt();
        out += stamp(fn(ms));
        last = m.capturedEnd();
    }
    return out + lrc.mid(last);
}

} // namespace Lrc
