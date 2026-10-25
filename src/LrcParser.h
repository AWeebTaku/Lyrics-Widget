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

} // namespace Lrc
