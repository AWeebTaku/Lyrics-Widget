#include "BrowserQueue.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpSocket>
#include <QTimer>

namespace {
constexpr int kMaxRequest = 512 * 1024; // a queue of hundreds of songs is well under this

QByteArray response(int code, const QByteArray &text, const QByteArray &body = {})
{
    return "HTTP/1.1 " + QByteArray::number(code) + " " + text + "\r\nContent-Length: " + QByteArray::number(body.size())
           + (body.isEmpty() ? "" : "\r\nContent-Type: application/json") + "\r\nConnection: close\r\n\r\n" + body;
}
} // namespace

BrowserQueue::BrowserQueue(QObject *parent) : QObject(parent)
{
    connect(&m_server, &QTcpServer::newConnection, this, &BrowserQueue::onConnection);
}

void BrowserQueue::configure(bool on, int port)
{
    if (m_server.isListening() && (!on || port != m_port))
        m_server.close();
    m_port = port;
    if (on && !m_server.isListening())
        m_server.listen(QHostAddress::LocalHost, quint16(port)); // loopback only
}

QList<Track> BrowserQueue::latest(int maxAgeSec) const
{
    return (m_have && m_age.elapsed() < maxAgeSec * 1000LL) ? m_tracks : QList<Track>();
}

void BrowserQueue::onConnection()
{
    while (QTcpSocket *s = m_server.nextPendingConnection()) {
        auto *buf = new QByteArray;
        connect(s, &QTcpSocket::readyRead, s, [this, s, buf] {
            *buf += s->readAll();
            const qsizetype hdrEnd = buf->indexOf("\r\n\r\n");
            if (buf->size() > kMaxRequest) {
                s->write(response(413, "Too Large"));
                s->disconnectFromHost();
                return;
            }
            if (hdrEnd < 0)
                return;
            const qsizetype len = QString::fromLatin1(buf->left(hdrEnd)).section(QStringLiteral("Content-Length:"), 1, 1,
                                      QString::SectionCaseInsensitiveSeps).section(QLatin1Char('\r'), 0, 0).trimmed().toLongLong();
            if (buf->size() < hdrEnd + 4 + len)
                return; // body still arriving
            handle(s, *buf);
            s->disconnectFromHost();
        });
        connect(s, &QTcpSocket::disconnected, s, [s, buf] { delete buf; s->deleteLater(); });
        QTimer::singleShot(5000, s, [s] { s->abort(); }); // never hold a socket open
    }
}

void BrowserQueue::handle(QTcpSocket *s, const QByteArray &req)
{
    const qsizetype hdrEnd = req.indexOf("\r\n\r\n");
    const QByteArray head = req.left(hdrEnd);
    const QByteArray line = head.left(head.indexOf("\r\n"));
    const QByteArray headLower = head.toLower();
    const bool fromExtension = headLower.contains("\r\norigin: chrome-extension://");
    const bool marked = headLower.contains("\r\nx-lyric-widget: 1");

    if (line.startsWith("GET /ping")) {
        s->write(response(200, "OK"));
    } else if (line.startsWith("GET /status")) {
        // what was received last: lets you check the extension without waiting for lyrics to appear
        QJsonArray first;
        for (const Track &t : m_tracks.mid(0, 5))
            first.append(QJsonObject{{QStringLiteral("title"), t.title}, {QStringLiteral("artist"), t.artist},
                                     {QStringLiteral("videoId"), t.id}, {QStringLiteral("durationSec"), t.durationSec}});
        s->write(response(200, "OK", QJsonDocument(QJsonObject{
            {QStringLiteral("received"), m_have},
            {QStringLiteral("ageSec"), m_have ? int(m_age.elapsed() / 1000) : -1},
            {QStringLiteral("currentVideoId"), m_currentId},
            {QStringLiteral("upNextCount"), int(m_tracks.size())},
            {QStringLiteral("upNext"), first}}).toJson(QJsonDocument::Compact)));
    } else if (line.startsWith("POST /queue") && fromExtension && marked) {
        parseQueue(req.mid(hdrEnd + 4));
        s->write(response(204, "No Content"));
    } else {
        s->write(response(403, "Forbidden"));
    }
}

void BrowserQueue::parseQueue(const QByteArray &body)
{
    const QJsonObject o = QJsonDocument::fromJson(body).object();
    if (o.isEmpty())
        return;
    QList<Track> out;
    for (const auto &v : o.value(QStringLiteral("next")).toArray()) {
        const QJsonObject t = v.toObject();
        Track tr;
        tr.id = t.value(QStringLiteral("videoId")).toString();
        tr.title = t.value(QStringLiteral("title")).toString().simplified();
        tr.artist = t.value(QStringLiteral("artist")).toString().simplified();
        tr.album = t.value(QStringLiteral("album")).toString().simplified();
        tr.durationSec = t.value(QStringLiteral("durationSec")).toInt();
        if (!tr.id.isEmpty() && !tr.title.isEmpty())
            out << tr;
    }
    m_tracks = out;
    m_currentId = o.value(QStringLiteral("currentVideoId")).toString();
    m_age.restart();
    m_have = true;
    emit received();
}
