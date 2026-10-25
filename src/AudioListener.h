#pragma once
#include <QObject>
#include <QProcess>
#include <QVector>
#include <functional>

// Listens to what the computer is playing (the default output's monitor, via `parec`; nothing from
// the microphone) and keeps a light 100 Hz picture of it: how strongly a voice-range sound starts at
// each moment of the song, plus beats and tempo. Only the numbers are kept, never the audio.
// Used to (1) estimate how far the lyrics' timestamps are off, (2) tell the beat for animations.
class AudioListener : public QObject
{
    Q_OBJECT
public:
    explicit AudioListener(QObject *parent = nullptr);
    ~AudioListener() override;

    using PositionFn = std::function<qint64()>; // media position (ms) right now
    void setPositionSource(PositionFn f) { m_pos = std::move(f); }
    void start();
    void stop();
    bool running() const { return m_proc.state() != QProcess::NotRunning; }
    void reset(); // new song: forget what was heard

    double bpm() const { return m_bpm; }

    // Where the voice starts, relative to the lyric stamps. offsetMs is what to ADD to the player
    // position so lines appear on time (negative = lyrics are early, show them later).
    struct Estimate {
        bool ok = false;
        int offsetMs = 0;
        double confidence = 0; // z-score of the peak; 5+ is trusted
        int lines = 0;         // how many lyric lines were usable
    };
    Estimate estimateOffset(const QVector<qint64> &stampsMs) const;

signals:
    void beat();
    void tempoChanged();

private:
    void onData();
    void frame(float vocal, float full, qint64 mediaMs);
    void updateTempo();

    struct Biquad {
        float b0 = 0, b1 = 0, b2 = 0, a1 = 0, a2 = 0, z1 = 0, z2 = 0;
        float run(float x) { const float y = b0 * x + z1; z1 = b1 * x - a1 * y + z2; z2 = b2 * x - a2 * y; return y; }
    };
    static Biquad design(bool highpass, float hz, float rate);

    QProcess m_proc;
    PositionFn m_pos;
    QByteArray m_buf;
    Biquad m_hp, m_lp;
    int m_inFrame = 0;
    double m_sumV = 0, m_sumF = 0;

    // vocal-band onset strength per 10 ms of media time; have = covered
    QVector<float> m_onset;
    QVector<quint8> m_have;
    // recent full-band onset history for beats and tempo
    QVector<float> m_recent;
    float m_lastEnvV = 0, m_lastEnvF = 0, m_meanV = 0, m_meanF = 0;
    qint64 m_lastBeatMs = -1000;
    int m_frames = 0;
    bool m_anchored = false;
    double m_anchorMs = 0;
    qint64 m_gridFrames = 0;
    double m_bpm = 0;
    QVector<double> m_bpmHist;
};
