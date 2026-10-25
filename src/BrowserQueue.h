#pragma once
#include <QList>
#include <QObject>
#include <QTcpServer>
#include <QElapsedTimer>
#include <QtQml/qqmlregistration.h>

#include "Text.h"

// Receives the browser's "up next" list (YouTube Music) from the companion Chrome extension, so
// lyrics can be fetched ahead of time. Listens on 127.0.0.1 only, opt-in, and only accepts
// POST /queue from a browser extension (Origin chrome-extension://...) carrying the widget's
// marker header, so ordinary web pages cannot talk to it.
class BrowserQueue : public QObject
{
    Q_OBJECT
public:
    explicit BrowserQueue(QObject *parent = nullptr);

    bool enabled() const { return m_server.isListening(); }
    int port() const { return m_port; }
    // Listens while `on`; (re)binds when the port changes.
    void configure(bool on, int port);
    // Upcoming tracks sent in the last `maxAgeSec` seconds (empty when stale).
    QList<Track> latest(int maxAgeSec = 90) const;
    QString currentVideoId() const { return m_currentId; }

signals:
    void received(); // a fresh queue arrived

private:
    void onConnection();
    void handle(class QTcpSocket *s, const QByteArray &req);
    void parseQueue(const QByteArray &body);

    QTcpServer m_server;
    int m_port = 8899;
    QList<Track> m_tracks;
    QString m_currentId;
    QElapsedTimer m_age;
    bool m_have = false;
};
