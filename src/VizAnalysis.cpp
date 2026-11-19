#include "VizAnalysis.h"

#include <algorithm>

void VizAnalysis::feed(const QList<int> &values, int range)
{
    if (range <= 0)
        return;
    std::vector<double> norm(values.size());
    for (qsizetype i = 0; i < values.size(); ++i)
        norm[i] = double(values[i]) / range;
    Viz::Settings s;
    s.smoothing = m_smoothing / 100.0;
    s.releaseMs = m_release;
    s.peakFall = m_peakFall / 100.0;
    s.bassWeight = m_bassW / 100.0;
    s.trebleWeight = m_trebleW / 100.0;
    s.taper = m_taper;
    s.spacing = m_spacing;
    s.lowHz = m_lowHz;
    s.highHz = m_highHz;
    const double dt = m_clock.isValid() ? m_clock.nsecsElapsed() / 1e6 : 16;
    m_clock.restart();
    m_frame = m_an.step(norm, dt, s);
    m_levels.resize(values.size());
    m_peaks.resize(values.size());
    for (qsizetype i = 0; i < values.size(); ++i) {
        m_levels[i] = int(std::lround(m_frame.level[i] * range));
        m_peaks[i] = int(std::lround(m_frame.peak[i] * range));
    }
    emit framed();
    if (m_frame.beatNow)
        emit beatFired();
}
