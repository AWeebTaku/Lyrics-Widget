#pragma once
#include <QStringList>
#include <QVector>
#include <algorithm>
#include <cmath>
#include <limits>

#include "LrcParser.h"

namespace RomanAlign {

// Pairs each original lyric line with its romanization line (parallel to `orig`, "" = none).
// The two usually come from different sources with different line breaks and timing:
//  - same number of text lines: pair them in order (timing may differ by seconds);
//  - otherwise estimate the time offset between the sources and match one-to-one in order,
//    with a tolerance tied to the spacing of the lines, so fast lyrics cannot pair with a
//    neighbouring line. `matched` (optional) receives how many lines were paired.
inline QStringList align(const QVector<LyricLine> &orig, const QVector<LyricLine> &rom, int *matched = nullptr)
{
    QStringList out;
    out.resize(orig.size());
    int hits = 0;
    QVector<int> O, R;
    for (int i = 0; i < orig.size(); ++i)
        if (!orig[i].text.isEmpty())
            O << i;
    for (int j = 0; j < rom.size(); ++j)
        if (!rom[j].text.isEmpty())
            R << j;
    auto finish = [&] { if (matched) *matched = hits; return out; };
    if (O.isEmpty() || R.isEmpty())
        return finish();

    if (O.size() == R.size()) {
        for (int k = 0; k < O.size(); ++k)
            out[O[k]] = rom[R[k]].text;
        hits = O.size();
        return finish();
    }

    // Time offset between the two timelines: try the differences between the first few lines of
    // each and keep the one that lines up the most lines (0 wins ties).
    auto lined = [&](qint64 off) {
        int n = 0, j2 = 0;
        for (int i : std::as_const(O)) {
            const qint64 t = orig[i].timeMs + off;
            while (j2 < R.size() && rom[R[j2]].timeMs < t - 350)
                ++j2;
            if (j2 < R.size() && std::abs(rom[R[j2]].timeMs - t) <= 350) {
                ++n;
                ++j2;
            }
        }
        return n;
    };
    qint64 offset = 0;
    int bestN = lined(0);
    for (int a = 0; a < std::min<int>(6, O.size()); ++a)
        for (int b = 0; b < std::min<int>(6, R.size()); ++b) {
            const qint64 off = rom[R[b]].timeMs - orig[O[a]].timeMs;
            const int n = lined(off);
            if (n > bestN || (n == bestN && std::abs(off) < std::abs(offset))) {
                bestN = n;
                offset = off;
            }
        }

    int j = 0;
    for (int k = 0; k < O.size(); ++k) {
        const qint64 t = orig[O[k]].timeMs + offset;
        const qint64 before = k > 0 ? orig[O[k]].timeMs - orig[O[k - 1]].timeMs : 100000;
        const qint64 after = k + 1 < O.size() ? orig[O[k + 1]].timeMs - orig[O[k]].timeMs : 100000;
        const qint64 tol = std::clamp<qint64>(qint64(0.45 * std::min(before, after)), 120, 800);
        while (j < R.size() && rom[R[j]].timeMs < t - tol)
            ++j;
        if (j < R.size() && std::abs(rom[R[j]].timeMs - t) <= tol) {
            out[O[k]] = rom[R[j]].text;
            ++j;
            ++hits;
        }
    }
    return finish();
}

} // namespace RomanAlign
