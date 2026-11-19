#pragma once
#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include "VizCore.h"

class VizAnalysis : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int smoothing MEMBER m_smoothing NOTIFY settingsChanged)      // 0..100, 0 = off
    Q_PROPERTY(int releaseMs MEMBER m_release NOTIFY settingsChanged)
    Q_PROPERTY(int peakFall MEMBER m_peakFall NOTIFY settingsChanged)        // 0..100
    Q_PROPERTY(int bassWeight MEMBER m_bassW NOTIFY settingsChanged)         // percent
    Q_PROPERTY(int trebleWeight MEMBER m_trebleW NOTIFY settingsChanged)     // percent
    Q_PROPERTY(bool taper MEMBER m_taper NOTIFY settingsChanged)
    Q_PROPERTY(int spacing MEMBER m_spacing NOTIFY settingsChanged)         // 0 as cava, 1 mel, 2 linear
    Q_PROPERTY(int lowHz MEMBER m_lowHz NOTIFY settingsChanged)
    Q_PROPERTY(int highHz MEMBER m_highHz NOTIFY settingsChanged)
    Q_PROPERTY(QList<qreal> bands READ bands NOTIFY framed)                   // eight band levels, 0..1
    Q_PROPERTY(QList<int> levels READ levels NOTIFY framed)   // smoothed, in the range cava was asked for
    Q_PROPERTY(QList<int> peaks READ peaks NOTIFY framed)
    Q_PROPERTY(qreal bass READ bass NOTIFY framed)
    Q_PROPERTY(qreal mid READ mid NOTIFY framed)
    Q_PROPERTY(qreal high READ high NOTIFY framed)
    Q_PROPERTY(qreal beat READ beat NOTIFY framed)
    Q_PROPERTY(bool silent READ silent NOTIFY framed)
    Q_PROPERTY(qreal silentMs READ silentMs NOTIFY framed)

public:
    explicit VizAnalysis(QObject *parent = nullptr) : QObject(parent) { m_clock.start(); }

    // values: cava's bars (0..range)
    Q_INVOKABLE void feed(const QList<int> &values, int range);

    QList<int> levels() const { return m_levels; }
    QList<int> peaks() const { return m_peaks; }
    QList<qreal> bands() const { return QList<qreal>(std::begin(m_frame.bands), std::end(m_frame.bands)); }
    qreal bass() const { return m_frame.bass; }
    qreal mid() const { return m_frame.mid; }
    qreal high() const { return m_frame.high; }
    qreal beat() const { return m_frame.beat; }
    bool silent() const { return m_frame.silent; }
    qreal silentMs() const { return m_frame.silentMs; }

signals:
    void settingsChanged();
    void framed();
    void beatFired();

private:
    Viz::Analyzer m_an;
    Viz::Frame m_frame;
    QList<int> m_levels, m_peaks;
    int m_smoothing = 0, m_release = 350, m_peakFall = 40, m_bassW = 100, m_trebleW = 100;
    bool m_taper = false;
    int m_spacing = 0, m_lowHz = 50, m_highHz = 10000;
    QElapsedTimer m_clock;
};
