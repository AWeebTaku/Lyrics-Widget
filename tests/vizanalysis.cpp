// Checks for the visualizer's analysis core (src/VizCore.h). No framework: exit code 1 on failure.
#include "VizCore.h"

#include <cstdio>

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { ++failures; std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } } while (0)

static std::vector<double> frame(double bass, double rest, size_t n = 20)
{
    std::vector<double> v(n, rest);
    for (size_t i = 0; i < n / 5; ++i)
        v[i] = bass;
    return v;
}

int main()
{
    Viz::Settings s;

    // smoothing 0 passes values through; the gate zeroes tiny ones
    {
        Viz::Analyzer a;
        const auto &f = a.step({0.5, 0.005, 1.0}, 16, s);
        CHECK(f.level[0] == 0.5 && f.level[1] == 0 && f.level[2] == 1.0);
    }
    // smoothing: rises quickly, falls slowly
    {
        Viz::Analyzer a;
        s.smoothing = 0.8;
        for (int i = 0; i < 10; ++i)
            a.step({1.0}, 16, s);
        const double up = a.step({1.0}, 16, s).level[0];
        const double after = a.step({0.0}, 16, s).level[0];
        CHECK(up > 0.8);
        CHECK(after > 0.5 && after < up); // fell, but not to zero in one frame
        s.smoothing = 0;
    }
    // peak caps fall at a steady rate and are lifted by the level
    {
        Viz::Analyzer a;
        a.step({1.0}, 16, s);
        const double p0 = a.step({0.0}, 100, s).peak[0];
        const double p1 = a.step({0.0}, 100, s).peak[0];
        CHECK(p0 < 1.0 && p1 < p0 && p0 - p1 > 0.01);
        CHECK(a.step({0.9}, 16, s).peak[0] >= 0.9);
    }
    // beat: fires on kicks (bass jumps above its average), not on steady bass, and not twice within 180 ms
    {
        Viz::Analyzer a;
        int beats = 0;
        for (int i = 0; i < 80; ++i) // steady loud bass for 1.3 s
            beats += a.step(frame(0.6, 0.2), 16, s).beatNow;
        CHECK(beats <= 1); // at most the onset
        beats = 0;
        for (int k = 0; k < 4; ++k) { // kicks every 500 ms: quiet, then loud
            for (int i = 0; i < 24; ++i)
                a.step(frame(0.05, 0.2), 16, s);
            for (int i = 0; i < 8; ++i)
                beats += a.step(frame(0.9, 0.2), 16, s).beatNow;
        }
        CHECK(beats == 4);
    }
    // a long silence uses the release time and reports silent
    {
        Viz::Analyzer a;
        s.smoothing = 0.5;
        for (int i = 0; i < 20; ++i)
            a.step({1.0, 1.0}, 16, s);
        bool silent = false;
        for (int i = 0; i < 100; ++i)
            silent = a.step({0.0, 0.0}, 16, s).silent;
        CHECK(silent);
        CHECK(a.step({0.0, 0.0}, 16, s).level[0] < 0.05);
        s.smoothing = 0;
    }
    // bass / treble weights tilt the bars; the taper softens the ends
    {
        Viz::Analyzer a;
        s.bassWeight = 1.0; s.trebleWeight = 0.5;
        const auto &f = a.step(std::vector<double>(11, 0.8), 16, s);
        CHECK(f.level[0] > f.level[10] && f.level[10] < 0.5);
        s.bassWeight = s.trebleWeight = 1.0;
        s.taper = true;
        Viz::Analyzer b;
        const auto &g = b.step(std::vector<double>(21, 0.8), 16, s);
        CHECK(g.level[0] < 0.1 && g.level[10] > 0.79);
    }
    // frequency axis: mel and linear re-space log-spaced bars; a rising input shows linear above mel above log
    {
        std::vector<double> ramp(40);
        for (size_t i = 0; i < ramp.size(); ++i)
            ramp[i] = double(i) / 39.0;
        const auto mel = Viz::respace(ramp, 1, 50, 10000), lin = Viz::respace(ramp, 2, 50, 10000);
        CHECK(Viz::respace(ramp, 0, 50, 10000) == ramp);
        CHECK(mel.size() == 40 && lin.size() == 40);
        CHECK(lin[20] > mel[20] && mel[20] > ramp[20]);
        bool rising = true;
        for (size_t i = 1; i < mel.size(); ++i)
            rising &= mel[i] >= mel[i - 1];
        CHECK(rising && std::abs(mel[0] - 0) < 1e-9 && std::abs(mel[39] - 1) < 1e-9);
    }
    // eight band levels: equal slices of the bars
    {
        Viz::Analyzer a;
        std::vector<double> v(16, 0.0);
        for (size_t i = 8; i < 10; ++i)
            v[i] = 1.0;   // the fifth slice
        const auto &f = a.step(v, 16, s);
        CHECK(f.bands[4] == 1.0 && f.bands[0] == 0 && f.bands[7] == 0);
    }
    // the number of bars may change between frames
    {
        Viz::Analyzer a;
        a.step(std::vector<double>(10, 0.5), 16, s);
        CHECK(a.step(std::vector<double>(30, 0.5), 16, s).level.size() == 30);
    }
    return failures ? 1 : 0;
}
