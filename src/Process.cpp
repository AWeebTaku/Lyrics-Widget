#include "Process.h"

Process::Process(QObject *parent) : QObject(parent)
{
    connect(&m_proc, &QProcess::readyReadStandardOutput, this, &Process::onOutput);
    connect(&m_proc, &QProcess::readyReadStandardError, this, [this] {
        m_err += QString::fromUtf8(m_proc.readAllStandardError());
        if (m_err.size() > 8192)
            m_err = m_err.right(8192);
        emit stderrChanged();
    });
    connect(&m_proc, &QProcess::stateChanged, this, [this] { emit runningChanged(); });
    connect(&m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            m_err = QStringLiteral("Failed to start: %1").arg(m_command.value(0));
            emit stderrChanged();
        }
    });
}

Process::~Process()
{
    m_proc.disconnect(this);
    m_proc.kill();
    m_proc.waitForFinished(300);
}

void Process::setCommand(const QStringList &c)
{
    if (c == m_command)
        return;
    m_command = c;
    emit commandChanged();
    if (!c.isEmpty())
        restart();
}

void Process::stop()
{
    if (m_proc.state() != QProcess::NotRunning) {
        m_proc.kill();
        m_proc.waitForFinished(300);
    }
    m_buf.clear();
}

void Process::restart()
{
    stop();
    if (m_command.isEmpty())
        return;
    m_err.clear();
    emit stderrChanged();
    m_proc.start(m_command.first(), m_command.mid(1));
}

void Process::onOutput()
{
    m_buf += m_proc.readAllStandardOutput();
    // Only the newest complete line matters; older frames are already stale.
    const qsizetype end = m_buf.lastIndexOf('\n');
    if (end < 0)
        return;
    const qsizetype start = m_buf.lastIndexOf('\n', end - 1) + 1;
    m_out = QString::fromUtf8(m_buf.mid(start, end - start));
    m_buf.remove(0, end + 1);
    emit stdoutChanged();
}
