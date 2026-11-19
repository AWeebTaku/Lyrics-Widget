#include "TrackDetails.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <cmath>

TrackDetails::TrackDetails(QObject *parent) : QObject(parent) {}

QNetworkReply *TrackDetails::get(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "LyricWidget/2.1 (https://github.com/AWeebTaku/Lyrics-Widget)"); // MusicBrainz asks for one
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(8000);
    ++m_pending;
    return m_nam.get(req);
}

void TrackDetails::clear()
{
    ++m_gen;
    m_cur = {};
    m_pending = 0;
    m_busy = false;
    m_key.clear();
    emit changed();
}

void TrackDetails::finish()
{
    if (--m_pending > 0)
        return;
    m_busy = false;
    m_cache.insert(m_key, m_cur);
    emit changed();
}

void TrackDetails::lookup(const QString &title, const QString &artist, const QString &album, double lengthSec)
{
    const QString key = title + QLatin1Char('\n') + artist + QLatin1Char('\n') + album;
    if (title.isEmpty() || key == m_key)
        return;
    ++m_gen;
    const quint64 gen = m_gen;
    m_key = key;
    m_cur = {};
    m_pending = 0;
    if (const auto it = m_cache.constFind(key); it != m_cache.constEnd()) {
        m_cur = *it;
        m_busy = false;
        emit changed();
        return;
    }
    m_busy = true;
    emit changed();

    // MusicBrainz: the recording, then its release for the label
    QString q = QStringLiteral("recording:\"%1\"").arg(QString(title).remove(QLatin1Char('"')));
    if (!artist.isEmpty())
        q += QStringLiteral(" AND artist:\"%1\"").arg(QString(artist).remove(QLatin1Char('"')));
    if (lengthSec > 0)
        q += QStringLiteral(" AND dur:[%1 TO %2]").arg(qint64((lengthSec - 5) * 1000)).arg(qint64((lengthSec + 5) * 1000));
    QUrl url(QStringLiteral("https://musicbrainz.org/ws/2/recording"));
    QUrlQuery uq;
    uq.addQueryItem(QStringLiteral("query"), q);
    uq.addQueryItem(QStringLiteral("fmt"), QStringLiteral("json"));
    uq.addQueryItem(QStringLiteral("limit"), QStringLiteral("3"));
    url.setQuery(uq);
    QNetworkReply *r = get(url);
    connect(r, &QNetworkReply::finished, this, [this, r, gen] {
        r->deleteLater();
        if (gen != m_gen)
            return;
        const QJsonArray recs = QJsonDocument::fromJson(r->readAll()).object().value(QStringLiteral("recordings")).toArray();
        QString releaseId;
        for (const auto &v : recs) {
            const QJsonObject rec = v.toObject();
            QStringList tags;
            for (const auto &t : rec.value(QStringLiteral("tags")).toArray())
                tags << t.toObject().value(QStringLiteral("name")).toString();
            const QJsonArray rels = rec.value(QStringLiteral("releases")).toArray();
            if (rels.isEmpty())
                continue;
            const QJsonObject rel = rels.first().toObject();
            m_cur.year = rel.value(QStringLiteral("date")).toString().left(4);
            m_cur.country = rel.value(QStringLiteral("country")).toString();
            m_cur.tags = tags.mid(0, 4).join(QStringLiteral(", "));
            releaseId = rel.value(QStringLiteral("id")).toString();
            break;
        }
        if (!releaseId.isEmpty()) {
            QNetworkReply *r2 = get(QUrl(QStringLiteral("https://musicbrainz.org/ws/2/release/%1?inc=labels&fmt=json").arg(releaseId)));
            connect(r2, &QNetworkReply::finished, this, [this, r2, gen] {
                r2->deleteLater();
                if (gen == m_gen) {
                    const QJsonArray li = QJsonDocument::fromJson(r2->readAll()).object().value(QStringLiteral("label-info")).toArray();
                    if (!li.isEmpty())
                        m_cur.label = li.first().toObject().value(QStringLiteral("label")).toObject().value(QStringLiteral("name")).toString();
                    finish();
                }
            });
        }
        if (gen == m_gen)
            finish();
    });

    // Wikipedia: the artist's summary
    if (!artist.isEmpty()) {
        QNetworkReply *w = get(QUrl(QStringLiteral("https://en.wikipedia.org/api/rest_v1/page/summary/") + QString::fromUtf8(QUrl::toPercentEncoding(QString(artist).replace(QLatin1Char(' '), QLatin1Char('_'))))));
        connect(w, &QNetworkReply::finished, this, [this, w, gen] {
            w->deleteLater();
            if (gen != m_gen)
                return;
            const QJsonObject o = QJsonDocument::fromJson(w->readAll()).object();
            QString text = o.value(QStringLiteral("extract")).toString();
            if (o.value(QStringLiteral("type")).toString() == QLatin1String("disambiguation"))
                text.clear();
            if (text.size() > 320)
                text = text.left(317).trimmed() + QStringLiteral("…");
            m_cur.about = text;
            finish();
        });
    }
}
