#include "SpotifyAccount.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QStandardPaths>
#include <QTcpSocket>
#include <QUrlQuery>
#include <QWebSocket>
#include <memory>

namespace {
constexpr quint16 kPort = 8898;
const QString kRedirect = QStringLiteral("http://127.0.0.1:8898/callback");

QString storePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/spotify.json");
}

QString randomUrlSafe(int bytes)
{
    QByteArray b(bytes, 0);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32 *>(b.data()), bytes / 4);
    return QString::fromLatin1(b.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}
} // namespace

SpotifyAccount::SpotifyAccount(QObject *parent) : QObject(parent)
{
    m_loginTimeout.setSingleShot(true);
    m_loginTimeout.setInterval(3 * 60 * 1000);
    connect(&m_loginTimeout, &QTimer::timeout, this, [this] {
        stopServer();
        setStatus(QStringLiteral("Sign-in timed out"));
    });
    load();
}

void SpotifyAccount::load()
{
    QFile f(storePath());
    m_access.clear(); m_refresh.clear(); m_expiresAt = 0;
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
        m_clientId = o.value(QStringLiteral("client_id")).toString();
        m_access = o.value(QStringLiteral("access_token")).toString();
        m_refresh = o.value(QStringLiteral("refresh_token")).toString();
        m_expiresAt = o.value(QStringLiteral("expires_at")).toInteger();
    }
    m_status = connected() ? QStringLiteral("Connected") : QStringLiteral("Not connected");
}

void SpotifyAccount::save() const
{
    QFile f(storePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner); // tokens: owner only
    f.write(QJsonDocument(QJsonObject{{QStringLiteral("client_id"), m_clientId},
                                      {QStringLiteral("access_token"), m_access},
                                      {QStringLiteral("refresh_token"), m_refresh},
                                      {QStringLiteral("expires_at"), m_expiresAt}}).toJson());
}

void SpotifyAccount::setStatus(const QString &s)
{
    m_status = s;
    emit changed();
}

void SpotifyAccount::reload()
{
    load();
    emit changed();
}

void SpotifyAccount::logout()
{
    stopServer();
    m_access.clear(); m_refresh.clear(); m_expiresAt = 0;
    QFile::remove(storePath());
    setStatus(QStringLiteral("Not connected"));
}

QString SpotifyAccount::pkceChallenge(const QString &verifier)
{
    return QString::fromLatin1(QCryptographicHash::hash(verifier.toLatin1(), QCryptographicHash::Sha256)
                                   .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

void SpotifyAccount::stopServer()
{
    m_loginTimeout.stop();
    if (m_server.isListening())
        m_server.close();
}

void SpotifyAccount::login(const QString &clientId)
{
    if (clientId.trimmed().isEmpty()) {
        setStatus(QStringLiteral("Enter your Spotify Client ID first"));
        return;
    }
    stopServer();
    if (!m_server.listen(QHostAddress::LocalHost, kPort)) {
        setStatus(QStringLiteral("Port %1 is busy; close whatever uses it and retry").arg(kPort));
        return;
    }
    m_clientId = clientId.trimmed();
    m_verifier = randomUrlSafe(48);
    m_state = randomUrlSafe(16);
    const QString challenge = pkceChallenge(m_verifier);

    // One-shot listener for the redirect back from accounts.spotify.com.
    disconnect(&m_server, &QTcpServer::newConnection, nullptr, nullptr);
    connect(&m_server, &QTcpServer::newConnection, this, [this] {
        QTcpSocket *s = m_server.nextPendingConnection();
        connect(s, &QTcpSocket::readyRead, this, [this, s] {
            const QByteArray req = s->readLine(4096); // "GET /callback?code=..&state=.. HTTP/1.1"
            const QList<QByteArray> parts = req.split(' ');
            const QUrl url(QStringLiteral("http://127.0.0.1") + QString::fromLatin1(parts.value(1)));
            if (url.path() != QLatin1String("/callback"))
                return; // favicon etc: keep waiting
            const QUrlQuery q(url);
            const bool good = q.queryItemValue(QStringLiteral("state")) == m_state
                              && !q.queryItemValue(QStringLiteral("code")).isEmpty();
            const QByteArray body = good ? "Connected. You can close this tab and return to the widget settings."
                                         : "Sign-in failed or was cancelled. You can close this tab.";
            s->write("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n" + body);
            s->disconnectFromHost();
            stopServer();
            if (!good) {
                setStatus(QStringLiteral("Sign-in failed or was cancelled"));
                return;
            }
            QUrlQuery form;
            form.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));
            form.addQueryItem(QStringLiteral("code"), q.queryItemValue(QStringLiteral("code")));
            form.addQueryItem(QStringLiteral("redirect_uri"), kRedirect);
            form.addQueryItem(QStringLiteral("client_id"), m_clientId);
            form.addQueryItem(QStringLiteral("code_verifier"), m_verifier);
            exchange(form, [this](bool ok) {
                setStatus(ok ? QStringLiteral("Connected")
                             : QStringLiteral("Token exchange failed (check the Client ID and redirect URI)"));
            });
        });
    });
    m_loginTimeout.start();
    setStatus(QStringLiteral("Waiting for you to approve in the browser…"));

    QUrl auth(QStringLiteral("https://accounts.spotify.com/authorize"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("client_id"), m_clientId);
    q.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    q.addQueryItem(QStringLiteral("redirect_uri"), kRedirect);
    q.addQueryItem(QStringLiteral("scope"), QStringLiteral("user-read-playback-state"));
    q.addQueryItem(QStringLiteral("state"), m_state);
    q.addQueryItem(QStringLiteral("code_challenge_method"), QStringLiteral("S256"));
    q.addQueryItem(QStringLiteral("code_challenge"), challenge);
    auth.setQuery(q);
    QDesktopServices::openUrl(auth);
}

// POST to the token endpoint (code exchange or refresh) and store the result.
void SpotifyAccount::exchange(const QUrlQuery &form, std::function<void(bool)> done)
{
    QNetworkRequest req(QUrl(QStringLiteral("https://accounts.spotify.com/api/token")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    req.setTransferTimeout(10000);
    QNetworkReply *r = m_nam.post(req, form.toString(QUrl::FullyEncoded).toUtf8());
    connect(r, &QNetworkReply::finished, this, [this, r, done = std::move(done)] {
        r->deleteLater();
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        if (r->error() != QNetworkReply::NoError || o.value(QStringLiteral("access_token")).toString().isEmpty()) {
            // An invalid_grant on refresh means access was revoked: forget the dead token.
            if (o.value(QStringLiteral("error")).toString() == QLatin1String("invalid_grant")) {
                m_refresh.clear();
                save();
            }
            done(false);
            emit changed();
            return;
        }
        m_access = o.value(QStringLiteral("access_token")).toString();
        if (const QString rt = o.value(QStringLiteral("refresh_token")).toString(); !rt.isEmpty())
            m_refresh = rt;
        m_expiresAt = QDateTime::currentMSecsSinceEpoch() + o.value(QStringLiteral("expires_in")).toInt(3600) * 1000 - 60000;
        save();
        done(true);
        emit changed();
    });
}

void SpotifyAccount::withToken(std::function<void(const QString &)> ok, std::function<void()> fail)
{
    if (m_refresh.isEmpty()) {
        fail();
        return;
    }
    if (!m_access.isEmpty() && QDateTime::currentMSecsSinceEpoch() < m_expiresAt) {
        ok(m_access);
        return;
    }
    QUrlQuery form;
    form.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));
    form.addQueryItem(QStringLiteral("refresh_token"), m_refresh);
    form.addQueryItem(QStringLiteral("client_id"), m_clientId);
    exchange(form, [this, ok, fail](bool good) { good ? ok(m_access) : fail(); });
}

void SpotifyAccount::fetchQueue(QueueCb cb)
{
    if (m_appQueue) {
        fetchFromApp([this, cb](bool ok, const QList<Track> &t) {
            if (ok || !connected())
                cb(ok, t);
            else
                fetchFromApi(cb); // app route unavailable: fall back to the account
        });
        return;
    }
    fetchFromApi(cb);
}

void SpotifyAccount::fetchFromApi(QueueCb cb)
{
    if (QDateTime::currentMSecsSinceEpoch() < m_blockedUntil) {
        cb(false, {});
        return;
    }
    load(); // the settings window may have connected/disconnected since
    withToken(
        [this, cb](const QString &token) {
            QNetworkRequest req(QUrl(QStringLiteral("https://api.spotify.com/v1/me/player/queue")));
            req.setRawHeader("Authorization", "Bearer " + token.toUtf8());
            req.setTransferTimeout(8000);
            QNetworkReply *r = m_nam.get(req);
            connect(r, &QNetworkReply::finished, this, [this, r, cb] {
                r->deleteLater();
                const int http = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                if (http == 429) { // honour Retry-After
                    m_blockedUntil = QDateTime::currentMSecsSinceEpoch()
                                     + std::max(r->rawHeader("Retry-After").toInt(), 30) * 1000LL;
                    cb(false, {});
                    return;
                }
                if (http == 401) {
                    m_expiresAt = 0; // refresh next time
                    cb(false, {});
                    return;
                }
                QList<Track> out;
                for (const auto &v : QJsonDocument::fromJson(r->readAll()).object()
                                         .value(QStringLiteral("queue")).toArray()) {
                    const QJsonObject o = v.toObject();
                    Track t;
                    t.id = o.value(QStringLiteral("id")).toString();
                    t.title = o.value(QStringLiteral("name")).toString();
                    t.album = o.value(QStringLiteral("album")).toObject().value(QStringLiteral("name")).toString();
                    t.artist = o.value(QStringLiteral("artists")).toArray().first().toObject()
                                   .value(QStringLiteral("name")).toString();
                    t.durationSec = int(o.value(QStringLiteral("duration_ms")).toDouble() / 1000);
                    if (!t.id.isEmpty() && !t.title.isEmpty())
                        out << t; // podcasts/ads have no track id or title
                }
                cb(http == 200 || http == 204, out);
            });
        },
        [cb] { cb(false, {}); });
}

// ---- Spotify app via its local DevTools port ---------------------------------------------

namespace {
// Read-only: returns the upcoming tracks (shuffle order included) as a JSON string.
const char *kQueueJs = R"JS((() => { try {
  const q = (Spicetify.Queue && Spicetify.Queue.nextTracks) || [];
  return JSON.stringify(q.map(t => { const c = t.contextTrack || {}, m = c.metadata || {};
    return { uri: c.uri, title: m.title, artist: m.artist_name, album: m.album_title, dur: m.duration }; }));
} catch (e) { return "null"; } })())JS";
}

void SpotifyAccount::fetchFromApp(QueueCb cb)
{
    auto done = std::make_shared<bool>(false);
    auto finish = [done, cb](bool ok, const QList<Track> &t) {
        if (*done)
            return;
        *done = true;
        cb(ok, t);
    };
    QNetworkRequest req(QUrl(QStringLiteral("http://127.0.0.1:%1/json").arg(m_port)));
    req.setTransferTimeout(2000);
    QNetworkReply *r = m_nam.get(req);
    connect(r, &QNetworkReply::finished, this, [this, r, finish] {
        r->deleteLater();
        QString wsUrl;
        for (const auto &v : QJsonDocument::fromJson(r->readAll()).array()) {
            const QJsonObject o = v.toObject(); // the player UI page, not the service workers
            if (o.value(QStringLiteral("type")).toString() == QLatin1String("page")
                && o.value(QStringLiteral("url")).toString().contains(QLatin1String("xpui")))
                wsUrl = o.value(QStringLiteral("webSocketDebuggerUrl")).toString();
        }
        if (wsUrl.isEmpty()) {
            finish(false, {});
            return;
        }
        auto *ws = new QWebSocket();
        auto *timeout = new QTimer(ws);
        timeout->setSingleShot(true);
        connect(timeout, &QTimer::timeout, ws, [ws, finish] { finish(false, {}); ws->abort(); ws->deleteLater(); });
        timeout->start(4000);
        connect(ws, &QWebSocket::connected, ws, [ws] {
            ws->sendTextMessage(QString::fromUtf8(QJsonDocument(QJsonObject{
                {QStringLiteral("id"), 1}, {QStringLiteral("method"), QStringLiteral("Runtime.evaluate")},
                {QStringLiteral("params"), QJsonObject{{QStringLiteral("expression"), QString::fromUtf8(kQueueJs)},
                                                       {QStringLiteral("returnByValue"), true}}}}).toJson(QJsonDocument::Compact)));
        });
        connect(ws, &QWebSocket::textMessageReceived, ws, [ws, finish](const QString &msg) {
            const QJsonObject o = QJsonDocument::fromJson(msg.toUtf8()).object();
            if (o.value(QStringLiteral("id")).toInt() != 1)
                return;
            const QJsonDocument arr = QJsonDocument::fromJson(o.value(QStringLiteral("result")).toObject()
                                          .value(QStringLiteral("result")).toObject()
                                          .value(QStringLiteral("value")).toString().toUtf8());
            QList<Track> out;
            for (const auto &v : arr.array()) {
                const QJsonObject t = v.toObject();
                const QString uri = t.value(QStringLiteral("uri")).toString(); // spotify:track:<id>
                if (!uri.startsWith(QLatin1String("spotify:track:")))
                    continue; // ads, episodes
                Track tr;
                tr.id = uri.mid(14);
                tr.title = t.value(QStringLiteral("title")).toString();
                tr.artist = t.value(QStringLiteral("artist")).toString();
                tr.album = t.value(QStringLiteral("album")).toString();
                tr.durationSec = t.value(QStringLiteral("dur")).toString().toInt() / 1000;
                if (!tr.title.isEmpty())
                    out << tr;
            }
            finish(arr.isArray(), out);
            ws->close();
            ws->deleteLater();
        });
        connect(ws, &QWebSocket::errorOccurred, ws, [ws, finish] { finish(false, {}); ws->deleteLater(); });
        ws->open(QUrl(wsUrl));
    });
}

void SpotifyAccount::probe()
{
    m_appStatus = QStringLiteral("Checking…");
    emit changed();
    fetchFromApp([this](bool ok, const QList<Track> &t) {
        m_appStatus = ok ? QStringLiteral("Connected: %1 upcoming songs readable").arg(t.size())
                         : QStringLiteral("Can't reach Spotify on port %1 (is it running with Spicetify's debug port?)").arg(m_port);
        emit changed();
    });
}

// Runs a JavaScript expression (returning a string, possibly via a Promise) inside the Spotify app
// through its debug port and hands back the string.
void SpotifyAccount::evalInApp(const QString &expression, std::function<void(bool, const QString &)> cb)
{
    auto done = std::make_shared<bool>(false);
    auto finish = [done, cb](bool ok, const QString &s) {
        if (*done)
            return;
        *done = true;
        cb(ok, s);
    };
    QNetworkRequest req(QUrl(QStringLiteral("http://127.0.0.1:%1/json").arg(m_port)));
    req.setTransferTimeout(2000);
    QNetworkReply *r = m_nam.get(req);
    connect(r, &QNetworkReply::finished, this, [r, finish, expression] {
        r->deleteLater();
        QString wsUrl;
        for (const auto &v : QJsonDocument::fromJson(r->readAll()).array()) {
            const QJsonObject o = v.toObject();
            if (o.value(QStringLiteral("type")).toString() == QLatin1String("page")
                && o.value(QStringLiteral("url")).toString().contains(QLatin1String("xpui")))
                wsUrl = o.value(QStringLiteral("webSocketDebuggerUrl")).toString();
        }
        if (wsUrl.isEmpty()) {
            finish(false, {});
            return;
        }
        auto *ws = new QWebSocket();
        auto *timeout = new QTimer(ws);
        timeout->setSingleShot(true);
        connect(timeout, &QTimer::timeout, ws, [ws, finish] { finish(false, {}); ws->abort(); ws->deleteLater(); });
        timeout->start(6000);
        connect(ws, &QWebSocket::connected, ws, [ws, expression] {
            ws->sendTextMessage(QString::fromUtf8(QJsonDocument(QJsonObject{
                {QStringLiteral("id"), 1}, {QStringLiteral("method"), QStringLiteral("Runtime.evaluate")},
                {QStringLiteral("params"), QJsonObject{{QStringLiteral("expression"), expression},
                                                       {QStringLiteral("awaitPromise"), true},
                                                       {QStringLiteral("returnByValue"), true}}}}).toJson(QJsonDocument::Compact)));
        });
        connect(ws, &QWebSocket::textMessageReceived, ws, [ws, finish](const QString &msg) {
            const QJsonObject o = QJsonDocument::fromJson(msg.toUtf8()).object();
            if (o.value(QStringLiteral("id")).toInt() != 1)
                return;
            const QJsonObject res = o.value(QStringLiteral("result")).toObject().value(QStringLiteral("result")).toObject();
            finish(res.value(QStringLiteral("type")).toString() == QLatin1String("string"),
                   res.value(QStringLiteral("value")).toString());
            ws->close();
            ws->deleteLater();
        });
        connect(ws, &QWebSocket::errorOccurred, ws, [ws, finish] { finish(false, {}); ws->deleteLater(); });
        ws->open(QUrl(wsUrl));
    });
}

namespace {
QString lrcStamp(qint64 ms)
{
    return QStringLiteral("[%1:%2.%3]").arg(ms / 60000, 2, 10, QLatin1Char('0'))
        .arg(ms / 1000 % 60, 2, 10, QLatin1Char('0')).arg(ms % 1000 / 10, 2, 10, QLatin1Char('0'));
}
}

void SpotifyAccount::fetchLyrics(const QString &trackId, LyricsCb cb)
{
    static const QRegularExpression safe(QStringLiteral("^[A-Za-z0-9]{10,30}$"));
    if (!safe.match(trackId).hasMatch()) {
        cb(false, {});
        return;
    }
    const QString js = QStringLiteral(
        "Spicetify.CosmosAsync.get('https://spclient.wg.spotify.com/color-lyrics/v2/track/%1"
        "?format=json&vocalRemoval=false&market=from_token').then(r => JSON.stringify({s: r.lyrics.syncType,"
        " p: r.lyrics.providerDisplayName, x: r.lyrics.lines.map(l => [l.startTimeMs, l.words, l.transliteratedWords || ''])}))"
        ".catch(() => 'null')").arg(trackId);
    evalInApp(js, [cb](bool ok, const QString &value) {
        const QJsonObject o = QJsonDocument::fromJson(value.toUtf8()).object();
        if (!ok || o.isEmpty()) {
            cb(false, {});
            return;
        }
        AppLyrics out;
        out.provider = o.value(QStringLiteral("p")).toString();
        const bool synced = o.value(QStringLiteral("s")).toString().endsWith(QLatin1String("_SYNCED"));
        bool anyRoman = false;
        for (const auto &v : o.value(QStringLiteral("x")).toArray()) {
            const QJsonArray a = v.toArray();
            QString words = a.at(1).toString().trimmed(), roman = a.at(2).toString().trimmed();
            if (words == QStringLiteral("♪")) // Spotify's "instrumental" marker; the widget draws its own
                words.clear();
            out.plain += words + QLatin1Char('\n');
            if (synced) {
                const qint64 ms = a.at(0).toString().toLongLong();
                out.synced += lrcStamp(ms) + words + QLatin1Char('\n');
                out.roman += lrcStamp(ms) + roman + QLatin1Char('\n');
                anyRoman |= !roman.isEmpty();
            }
        }
        if (!anyRoman)
            out.roman.clear();
        cb(synced ? !out.synced.isEmpty() : !out.plain.isEmpty(), out);
    });
}
