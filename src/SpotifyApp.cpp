#include "SpotifyApp.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QWebSocket>
#include <memory>

SpotifyApp::SpotifyApp(QObject *parent) : QObject(parent) {}

// Upcoming songs (shuffle order included), read from the running app.
void SpotifyApp::fetchQueue(QueueCb cb)
{
    fetchFromApp(cb);
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

void SpotifyApp::fetchFromApp(QueueCb cb)
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

void SpotifyApp::probe()
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
void SpotifyApp::evalInApp(const QString &expression, std::function<void(bool, const QString &)> cb)
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

void SpotifyApp::fetchLyrics(const QString &trackId, LyricsCb cb)
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
