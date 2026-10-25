#include "AudioListener.h"

#include <algorithm>
#include <cmath>

namespace {
constexpr int kRate = 16000;
constexpr int kFrameSamples = kRate / 100;   // 10 ms
constexpr int kMaxFrames = 360000;           // one hour
constexpr int kInputLatencyMs = 30;          // audio reaches us this long after the player's position
constexpr int kLagMin = -200, kLagMax = 250; // search window around a stamp, in frames (-2 s .. +2.5 s)
constexpr int kBiasMs = 100;                 // lyric stamps conventionally sit ~0.1 s before the voice
}

AudioListener::Biquad AudioListener::design(bool highpass, float hz, float rate)
{
    const float w = 2.f * float(M_PI) * hz / rate, c = std::cos(w), alpha = std::sin(w) / (2.f * 0.7071f);
    const float a0 = 1.f + alpha;
    Biquad f;
    f.b0 = (highpass ? (1.f + c) : (1.f - c)) / 2.f / a0;
    f.b1 = (highpass ? -(1.f + c) : (1.f - c)) / a0;
    f.b2 = f.b0;
    f.a1 = -2.f * c / a0;
    f.a2 = (1.f - alpha) / a0;
    return f;
}

AudioListener::AudioListener(QObject *parent) : QObject(parent)
{
    connect(&m_proc, &QProcess::readyReadStandardOutput, this, &AudioListener::onData);
    connect(&m_proc, &QProcess::errorOccurred, this, [](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            qWarning("lyric-widget: 'parec' (pulseaudio-utils / pipewire-pulse) not found; audio listening is off");
    });
}

AudioListener::~AudioListener()
{
    m_proc.disconnect(this);
    m_proc.kill();
    m_proc.waitForFinished(300);
}

void AudioListener::start()
{
    if (running())
        return;
    m_hp = design(true, 300.f, kRate);
    m_lp = design(false, 3400.f, kRate);
    m_inFrame = 0;
    m_sumV = m_sumF = 0;
    m_buf.clear();
    // the default output's monitor: what is being played, nothing from the microphone
    m_proc.start(QStringLiteral("parec"),
                 {QStringLiteral("-d"), QStringLiteral("@DEFAULT_MONITOR@"), QStringLiteral("--format=s16le"),
                  QStringLiteral("--rate=%1").arg(kRate), QStringLiteral("--channels=1"),
                  QStringLiteral("--latency-msec=20")});
}

void AudioListener::stop()
{
    if (!running())
        return;
    m_proc.disconnect(this);
    m_proc.kill();
    m_proc.waitForFinished(300);
    connect(&m_proc, &QProcess::readyReadStandardOutput, this, &AudioListener::onData);
}

void AudioListener::reset()
{
    m_anchored = false;
    m_bpmHist.clear();
    m_onset.clear();
    m_have.clear();
    m_recent.clear();
    m_bpm = 0;
    m_frames = 0;
    emit tempoChanged();
}

void AudioListener::onData()
{
    m_buf += m_proc.readAllStandardOutput();
    const int nSamples = int(m_buf.size() / 2);
    if (nSamples == 0 || !m_pos)
        return;
    const auto *s = reinterpret_cast<const qint16 *>(m_buf.constData());
    const int frames = (m_inFrame + nSamples) / kFrameSamples;
    // Frame times: a steady 10 ms grid anchored to the player position. A chunk's own arrival time
    // is jittery, so the anchor only follows it slowly -- unless the player jumped (a seek).
    const double measured = double(m_pos()) - kInputLatencyMs - (frames > 0 ? (frames - 1) * 10.0 : 0.0)
                            - 0.0;
    if (!m_anchored || std::abs(measured - (m_anchorMs + m_gridFrames * 10.0)) > 250) {
        m_anchorMs = measured;
        m_gridFrames = 0;
        m_anchored = true;
    } else {
        m_anchorMs += 0.05 * (measured - (m_anchorMs + m_gridFrames * 10.0));
    }
    for (int i = 0; i < nSamples; ++i) {
        const float x = s[i] / 32768.f;
        const float v = m_lp.run(m_hp.run(x));
        m_sumV += double(v) * v;
        m_sumF += double(x) * x;
        if (++m_inFrame == kFrameSamples) {
            const qint64 t = qint64(m_anchorMs + m_gridFrames * 10.0);
            ++m_gridFrames;
            frame(float(std::sqrt(m_sumV / kFrameSamples)), float(std::sqrt(m_sumF / kFrameSamples)), t);
            m_inFrame = 0;
            m_sumV = m_sumF = 0;
        }
    }
    m_buf.remove(0, nSamples * 2);
}

void AudioListener::frame(float vocal, float full, qint64 mediaMs)
{
    const float envV = 20.f * std::log10(1e-5f + vocal), envF = 20.f * std::log10(1e-5f + full);
    const float onV = std::max(0.f, envV - m_meanV), onF = std::max(0.f, envF - m_meanF);
    m_meanV += 0.25f * (envV - m_meanV);
    m_meanF += 0.25f * (envF - m_meanF);

    const qint64 idx = mediaMs / 10;
    if (idx >= 0 && idx < kMaxFrames) {
        if (idx >= m_onset.size()) {
            m_onset.resize(idx + 1, 0.f);
            m_have.resize(idx + 1, 0);
        }
        m_onset[idx] = onV;
        m_have[idx] = 1;
    }

    m_recent.push_back(onF);
    if (m_recent.size() > 1200)
        m_recent.remove(0, m_recent.size() - 1200);
    ++m_frames;

    // beat: a clear jump in loudness, well above the last two seconds, not twice within 280 ms
    if (m_recent.size() > 100 && onF > 3.f && m_frames - int(m_lastBeatMs) > 28) {
        const int n = std::min<int>(m_recent.size(), 200);
        double mean = 0, var = 0;
        for (int i = m_recent.size() - n; i < m_recent.size(); ++i)
            mean += m_recent[i];
        mean /= n;
        for (int i = m_recent.size() - n; i < m_recent.size(); ++i)
            var += (m_recent[i] - mean) * (m_recent[i] - mean);
        if (onF > mean + 1.5 * std::sqrt(var / n)) {
            m_lastBeatMs = m_frames;
            emit beat();
        }
    }
    if (m_frames % 300 == 0)
        updateTempo();
}

// Tempo: autocorrelation of the recent loudness jumps, lags 0.24 s .. 1 s, folded into 70..160 BPM.
void AudioListener::updateTempo()
{
    const int n = m_recent.size();
    if (n < 600)
        return;
    double energy = 0;
    for (float x : std::as_const(m_recent))
        energy += double(x) * x;
    if (energy < 1)
        return;
    double best = 0;
    int bestLag = 0;
    for (int lag = 24; lag <= 100; ++lag) {
        double r = 0;
        for (int i = lag; i < n; ++i)
            r += double(m_recent[i]) * m_recent[i - lag];
        r /= (n - lag);
        if (r > best) {
            best = r;
            bestLag = lag;
        }
    }
    if (!bestLag)
        return;
    double bpm = 6000.0 / bestLag;
    while (bpm < 70)
        bpm *= 2;
    while (bpm > 160)
        bpm /= 2;
    // median of the last few readings: one bad window can't swing the tempo
    m_bpmHist.push_back(bpm);
    if (m_bpmHist.size() > 7)
        m_bpmHist.remove(0);
    QVector<double> sorted = m_bpmHist;
    std::sort(sorted.begin(), sorted.end());
    const double next = sorted[sorted.size() / 2];
    if (std::abs(next - m_bpm) > 1) {
        m_bpm = next;
        emit tempoChanged();
    }
}

AudioListener::Estimate AudioListener::estimateOffset(const QVector<qint64> &stamps) const
{
    Estimate e;
    const int span = kLagMax - kLagMin + 1;
    // light smoothing of the onset curve (+-20 ms)
    QVector<float> o(m_onset.size(), 0.f);
    for (int i = 2; i + 2 < m_onset.size(); ++i)
        o[i] = (m_onset[i - 2] + 2 * m_onset[i - 1] + 3 * m_onset[i] + 2 * m_onset[i + 1] + m_onset[i + 2]) / 9.f;

    QVector<double> P(span, 0.0);
    qint64 prev = -1'000'000;
    for (qint64 st : stamps) {
        const qint64 gap = st - prev;
        prev = st;
        if (gap < 700 || st < 4000) // a line that follows another with no pause has no clear start
            continue;
        const qint64 c = st / 10, lo = c + kLagMin, hi = c + kLagMax;
        if (lo < 0 || hi >= o.size())
            continue;
        int heard = 0;
        for (qint64 i = lo; i <= hi; ++i)
            heard += m_have[i];
        if (heard < 0.95 * span)
            continue;
        double mean = 0, var = 0;
        for (qint64 i = lo; i <= hi; ++i)
            mean += o[i];
        mean /= span;
        for (qint64 i = lo; i <= hi; ++i)
            var += (o[i] - mean) * (o[i] - mean);
        const double sd = std::sqrt(var / span);
        if (sd < 0.05)
            continue; // silence
        for (int k = 0; k < span; ++k)
            P[k] += (o[lo + k] - mean) / sd;
        ++e.lines;
    }
    if (e.lines < 8)
        return e;

    double mean = 0, var = 0;
    int peak = 0;
    for (int k = 0; k < span; ++k) {
        mean += P[k];
        if (P[k] > P[peak])
            peak = k;
    }
    mean /= span;
    for (int k = 0; k < span; ++k)
        var += (P[k] - mean) * (P[k] - mean);
    const double sd = std::sqrt(var / span);
    if (sd <= 0 || peak < 5 || peak > span - 6) // a peak at the edge of the window is no peak
        return e;
    e.confidence = (P[peak] - mean) / sd;
    const int lagMs = (peak + kLagMin) * 10 - kBiasMs; // where the voice starts vs where it should
    e.offsetMs = -lagMs;
    e.ok = e.confidence >= 5 && e.lines >= 10 && std::abs(e.offsetMs) >= 250 && std::abs(e.offsetMs) <= 2000;
    return e;
}
