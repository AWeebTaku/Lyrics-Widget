#pragma once
#include <algorithm>
#include <cmath>
#include <vector>

// Turns cava's bar values into what the visualizer styles and effects draw from: smoothed levels with a release,
// falling peak caps, bass / mid / high levels and a beat pulse. cava only gives binned values (no raw FFT), so all
// of this works from those bands.
namespace Viz {

struct Settings {
    double smoothing = 0;      // 0..1: 0 passes the values through untouched
    double releaseMs = 350;    // how long the bars take to fall back when the music stops
    double peakFall = 0.4;     // 0..1: how fast the peak caps fall (1 = quick)
    double bassWeight = 1;     // gain at the lowest band ... (1 = unchanged)
    double trebleWeight = 1;   // ... and at the highest, interpolated between
    double gate = 0.012;       // values below this (of full scale) count as silence
    bool taper = false;        // soften the outermost 15% of the bars at each end
    int spacing = 0;           // frequency axis: 0 as cava gives it (logarithmic), 1 mel, 2 linear
    double lowHz = 50, highHz = 10000; // the range the bars cover (cava's cutoff settings)
};

// Re-spaces bars that are log-spaced between lowHz and highHz onto a mel or linear frequency axis (same count),
// by interpolating between neighbouring bars. spacing 0 returns the input.
inline std::vector<double> respace(const std::vector<double> &in, int spacing, double lowHz, double highHz)
{
    const size_t n = in.size();
    if (spacing == 0 || n < 3 || lowHz <= 0 || highHz <= lowHz)
        return in;
    auto mel = [](double f) { return 2595.0 * std::log10(1.0 + f / 700.0); };
    auto unmel = [](double m) { return 700.0 * (std::pow(10.0, m / 2595.0) - 1.0); };
    std::vector<double> out(n);
    for (size_t j = 0; j < n; ++j) {
        const double u = double(j) / double(n - 1);
        const double f = spacing == 1 ? unmel(mel(lowHz) + u * (mel(highHz) - mel(lowHz))) : lowHz + u * (highHz - lowHz);
        const double k = std::clamp(std::log(std::max(f, lowHz) / lowHz) / std::log(highHz / lowHz), 0.0, 1.0) * double(n - 1);
        const size_t k0 = std::min(size_t(k), n - 2);
        const double t = k - double(k0);
        out[j] = in[k0] * (1 - t) + in[k0 + 1] * t;
    }
    return out;
}

struct Frame {
    std::vector<double> level; // 0..1, smoothed
    std::vector<double> peak;  // 0..1, falling caps
    double bass = 0, mid = 0, high = 0; // 0..1, from the raw bands (weights do not change them)
    double bands[8] = {0, 0, 0, 0, 0, 0, 0, 0}; // eight equal slices of the bars, 0..1, for the shader styles
    double beat = 0;           // 1 at a beat, decays in about a quarter of a second
    bool beatNow = false;      // true on the frame a beat was detected
    bool silent = true;
    double silentMs = 0;       // how long it has been silent
};

class Analyzer
{
public:
    // norm: one value per bar, 0..1 (value / the range cava was told); dtMs: time since the last frame
    const Frame &step(const std::vector<double> &input, double dtMs, const Settings &s)
    {
        const std::vector<double> norm = respace(input, s.spacing, s.lowHz, s.highHz);
        const size_t n = norm.size();
        if (n != f.level.size()) {
            f.level.assign(n, 0);
            f.peak.assign(n, 0);
        }
        dtMs = std::clamp(dtMs, 0.5, 200.0);
        f.beatNow = false;

        // band groups from the raw values
        double lo = 0, mi = 0, hi = 0;
        const size_t a = n / 5, b = a + (n * 2) / 5;
        size_t cl = 0, cm = 0, ch = 0;
        double top = 0;
        for (size_t i = 0; i < n; ++i) {
            const double x = std::clamp(norm[i], 0.0, 1.0);
            top = std::max(top, x);
            if (i < a) { lo += x; ++cl; } else if (i < b) { mi += x; ++cm; } else { hi += x; ++ch; }
        }
        f.bass = cl ? lo / cl : 0;
        f.mid = cm ? mi / cm : 0;
        f.high = ch ? hi / ch : 0;
        for (int k = 0; k < 8; ++k) {
            double sum = 0;
            size_t c = 0;
            for (size_t i = n * k / 8; i < n * (k + 1) / 8; ++i, ++c)
                sum += std::clamp(norm[i], 0.0, 1.0);
            f.bands[k] = c ? sum / c : 0;
        }
        f.silent = top < s.gate;
        silentMs = f.silent ? silentMs + dtMs : 0;
        f.silentMs = silentMs;

        // smoothing: quick to rise, slower to fall; a long silence uses the release time
        const double tauUp = 8 + s.smoothing * 90;
        const double tauDown = silentMs > 300 ? std::max(40.0, s.releaseMs) : 25 + s.smoothing * 260;
        const double up = 1 - std::exp(-dtMs / tauUp), down = 1 - std::exp(-dtMs / tauDown);
        for (size_t i = 0; i < n; ++i) {
            const double t = n > 1 ? double(i) / double(n - 1) : 0;
            double x = std::clamp(norm[i], 0.0, 1.0) * (s.bassWeight * (1 - t) + s.trebleWeight * t);
            x = x < s.gate ? 0 : std::min(1.0, x);
            if (s.taper) {
                const double e = std::min(t, 1 - t);
                if (e < 0.15)
                    x *= 0.5 - 0.5 * std::cos(M_PI * e / 0.15);
            }
            double &l = f.level[i];
            l = s.smoothing <= 0 ? x : l + (x - l) * (x > l ? up : down);
            // the caps fall at a steady rate and are pushed up by the level
            const double fall = (0.2 + 1.4 * s.peakFall) * dtMs / 1000.0;
            f.peak[i] = std::max(l, f.peak[i] - fall);
        }

        // beat: the bass jumps above its own slow average, with a minimum time between beats
        env += (f.bass - env) * (1 - std::exp(-dtMs / 150.0));
        sinceBeat += dtMs;
        if (f.bass - env < 0.04)
            armed = true; // the bass has dropped back: the next jump is a new beat, not the same one still going
        if (armed && f.bass > 0.25 && f.bass - env > 0.12 && sinceBeat > 180) {
            f.beatNow = true;
            f.beat = 1;
            sinceBeat = 0;
            armed = false;
        } else {
            f.beat *= std::exp(-dtMs / 220.0);
        }
        return f;
    }

private:
    Frame f;
    double env = 0, sinceBeat = 1000, silentMs = 0;
    bool armed = true;
};

} // namespace Viz

