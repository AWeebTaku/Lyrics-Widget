#pragma once
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <functional>

#include "Text.h"

// Talks to the running Spotify app through its local DevTools port (Spicetify installs expose one,
// default 8088): one read-only query at a time, no account, no developer app. It reads
//  - the "up next" queue (shuffle order included), so lyrics can be fetched before a song starts;
//  - the lyrics Spotify itself shows for a track id (exact, nothing to match).
class SpotifyApp : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool appQueue READ appQueue WRITE setAppQueue NOTIFY changed)
    Q_PROPERTY(int debugPort READ debugPort WRITE setDebugPort NOTIFY changed)
    Q_PROPERTY(QString appStatus READ appStatus NOTIFY changed)

public:
    explicit SpotifyApp(QObject *parent = nullptr);

    bool appQueue() const { return m_appQueue; }
    int debugPort() const { return m_port; }
    QString appStatus() const { return m_appStatus; }
    void setAppQueue(bool on) { if (on != m_appQueue) { m_appQueue = on; emit changed(); } }
    void setDebugPort(int p) { if (p != m_port) { m_port = p; emit changed(); } }
    Q_INVOKABLE void probe(); // test the connection and report in appStatus

    struct AppLyrics {
        QString synced;   // LRC
        QString plain;
        QString roman;    // LRC of Spotify's own transliteration, when it has one
        QString provider; // "Musixmatch", ...
    };
    using LyricsCb = std::function<void(bool ok, const AppLyrics &)>;
    void fetchLyrics(const QString &trackId, LyricsCb cb); // ok=false: app unreachable or no lyrics

    using QueueCb = std::function<void(bool ok, const QList<Track> &upNext)>;
    void fetchQueue(QueueCb cb);

signals:
    void changed();

private:
    void fetchFromApp(QueueCb cb);
    void evalInApp(const QString &expression, std::function<void(bool, const QString &)> cb);

    QNetworkAccessManager m_nam;
    bool m_appQueue = true;
    int m_port = 8088;
    QString m_appStatus;
};
