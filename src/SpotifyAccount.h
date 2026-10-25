#pragma once
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTcpServer>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <functional>

#include "Text.h"

// Two ways to read Spotify's "up next" queue, so lyrics can be fetched before a song starts:
//  1. the running Spotify app itself, through its local DevTools port (Spicetify installs expose
//     one, default 8088): one read-only query of Spicetify.Queue, no account, no developer app;
//  2. the Web API with a Spotify account (below), for setups without Spicetify.
//
// Spotify account via OAuth (Authorization Code + PKCE: no client secret). Used to read the
// "up next" queue so lyrics can be fetched before a song starts. Only the
// user-read-playback-state scope is requested. Tokens live in <appdata>/spotify.json (0600).
//
// The user brings their own (free) developer app: Client ID, with the redirect URI
// http://127.0.0.1:8898/callback registered on it.
class SpotifyAccount : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString clientId READ clientId NOTIFY changed)
    Q_PROPERTY(bool appQueue READ appQueue WRITE setAppQueue NOTIFY changed)   // read from the app
    Q_PROPERTY(int debugPort READ debugPort WRITE setDebugPort NOTIFY changed)
    Q_PROPERTY(QString appStatus READ appStatus NOTIFY changed)

public:
    explicit SpotifyAccount(QObject *parent = nullptr);

    bool connected() const { return !m_refresh.isEmpty(); }
    QString status() const { return m_status; }
    QString clientId() const { return m_clientId; }
    bool appQueue() const { return m_appQueue; }
    int debugPort() const { return m_port; }
    QString appStatus() const { return m_appStatus; }
    void setAppQueue(bool on) { if (on != m_appQueue) { m_appQueue = on; emit changed(); } }
    void setDebugPort(int p) { if (p != m_port) { m_port = p; emit changed(); } }
    bool canFetch() const { return m_appQueue || connected(); }
    Q_INVOKABLE void probe(); // test the Spotify-app route and report in appStatus

    // Spotify's own lyrics for a track (what the app itself shows), asked of the running app. Exact by
    // track id, so no title/artist matching. ok=false when the app is unreachable or has none.
    struct AppLyrics {
        QString synced;   // LRC
        QString plain;
        QString roman;    // LRC of Spotify's own transliteration, when it has one
        QString provider; // "Musixmatch", ...
    };
    using LyricsCb = std::function<void(bool ok, const AppLyrics &)>;
    void fetchLyrics(const QString &trackId, LyricsCb cb);

    Q_INVOKABLE void login(const QString &clientId);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void reload(); // another instance (settings window) may have logged in

    static QString pkceChallenge(const QString &verifier); // S256, base64url, no padding

    using QueueCb = std::function<void(bool ok, const QList<Track> &upNext)>;
    void fetchQueue(QueueCb cb);

signals:
    void changed();

private:
    void load();
    void save() const;
    void setStatus(const QString &s);
    void exchange(const QUrlQuery &form, std::function<void(bool)> done);
    void withToken(std::function<void(const QString &)> ok, std::function<void()> fail);
    void stopServer();
    void fetchFromApp(QueueCb cb);
    void evalInApp(const QString &expression, std::function<void(bool, const QString &)> cb);
    void fetchFromApi(QueueCb cb);

    QNetworkAccessManager m_nam;
    QTcpServer m_server;
    QTimer m_loginTimeout;
    QString m_clientId, m_access, m_refresh, m_status, m_verifier, m_state;
    qint64 m_expiresAt = 0;     // ms since epoch
    qint64 m_blockedUntil = 0;  // after a 429
    bool m_appQueue = false;
    int m_port = 8088;
    QString m_appStatus;
};
