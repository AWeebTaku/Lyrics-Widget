#pragma once
#include "LrcParser.h"
#include "Text.h"

// Community-uploaded synced lyrics sometimes skip a verse. The same upload usually carries the full
// plain text, so: match each synced line to the plain text, and put the plain lines that fall in a
// long hole back in, with estimated times spread across the hole. Returns how many lines were added.
namespace GapFill {

constexpr qint64 kHoleMs = 50000;

inline int fill(QVector<LyricLine> &lrc, const QString &plain)
{
    // plain lines without section headers like "[Chorus]"
    QStringList P;
    for (QString l : plain.split(QLatin1Char('\n'))) {
        l = l.trimmed();
        if (!l.isEmpty() && !(l.startsWith(QLatin1Char('[')) && l.endsWith(QLatin1Char(']'))))
            P << l;
    }
    if (P.size() < 4 || lrc.size() < 4)
        return 0;

    // map[i] = plain lines [first, end) that synced line i covers; plain text may wrap one lyric
    // line over several rows, so try 1..3 rows
    struct Span { int first = -1, end = -1; };
    QVector<Span> map(lrc.size());
    int pos = 0;
    for (qsizetype i = 0; i < lrc.size(); ++i) {
        if (lrc[i].text.isEmpty())
            continue;
        double best = 0.7;
        Span hit;
        // after a hole in the timing, the matching text can be many rows further on
        const bool afterHole = i > 0 && lrc[i].timeMs - lrc[i - 1].timeMs > kHoleMs;
        for (int k = pos; k < std::min<int>(P.size(), afterHole ? P.size() : pos + 10); ++k) {
            QString cand;
            for (int n = 1; n <= 3 && k + n <= P.size(); ++n) {
                cand += (n > 1 ? QStringLiteral(" ") : QString()) + P[k + n - 1];
                const double s = Text::similarityRaw(lrc[i].text, cand);
                if (s > best + 1e-9) {
                    best = s;
                    hit = {k, k + n};
                }
            }
        }
        if (hit.first >= 0) {
            map[i] = hit;
            pos = hit.end;
        }
    }

    QVector<LyricLine> add;
    for (qsizetype i = 0; i + 1 < lrc.size(); ++i) {
        const qint64 t0 = lrc[i].timeMs, t1 = lrc[i + 1].timeMs;
        if (t1 - t0 <= kHoleMs || map[i].first < 0 || map[i + 1].first < 0)
            continue;
        const int a = map[i].end, b = map[i + 1].first;
        if (b <= a)
            continue;
        // weight by length so a long line gets more time; keep ~4 s per line at most, centred in the hole
        double total = 0;
        for (int k = a; k < b; ++k)
            total += std::max<qsizetype>(8, P[k].size());
        const qint64 room = (t1 - 2500) - (t0 + 3500);
        const qint64 span = std::min<qint64>(room, qint64(b - a) * 4500);
        qint64 at = t0 + 3500 + (room - span) / 2;
        for (int k = a; k < b; ++k) {
            add.push_back({at, P[k]});
            at += qint64(span * std::max<qsizetype>(8, P[k].size()) / total);
        }
    }
    lrc += add;
    std::stable_sort(lrc.begin(), lrc.end(), [](const LyricLine &x, const LyricLine &y) { return x.timeMs < y.timeMs; });
    return int(add.size());
}

} // namespace GapFill
