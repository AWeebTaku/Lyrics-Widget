#pragma once
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Runs a command and exposes its output to QML: `stdout` holds the newest complete line (a
// cava frame), `stderr` everything written so far. Setting `command` (re)starts it; stop() halts
// it until restart() or a new command. This is what the audio visualizer feeds cava through.
class Process : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(QString stdout READ out NOTIFY stdoutChanged)
    Q_PROPERTY(QString stderr READ err NOTIFY stderrChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit Process(QObject *parent = nullptr);
    ~Process() override;

    QStringList command() const { return m_command; }
    QString out() const { return m_out; }
    QString err() const { return m_err; }
    bool running() const { return m_proc.state() != QProcess::NotRunning; }
    void setCommand(const QStringList &c);

    Q_INVOKABLE void restart();
    Q_INVOKABLE void stop();

signals:
    void commandChanged();
    void stdoutChanged();
    void stderrChanged();
    void runningChanged();

private:
    void onOutput();

    QProcess m_proc;
    QStringList m_command;
    QByteArray m_buf;
    QString m_out, m_err;
};
