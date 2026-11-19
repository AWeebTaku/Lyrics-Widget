#pragma once
#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

// Online facts about the playing song for the card's details view: release year, country, label and tags from
// MusicBrainz, and a short text about the artist from English Wikipedia. Off unless the user turns it on: a lookup
// sends the song's title, artist, album and length to MusicBrainz, and the artist's name to Wikipedia.
class TrackDetails : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString year READ year NOTIFY changed)
    Q_PROPERTY(QString country READ country NOTIFY changed)
    Q_PROPERTY(QString label READ label NOTIFY changed)
    Q_PROPERTY(QString tags READ tags NOTIFY changed)
    Q_PROPERTY(QString about READ about NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)

public:
    explicit TrackDetails(QObject *parent = nullptr);

    QString year() const { return m_cur.year; }
    QString country() const { return m_cur.country; }
    QString label() const { return m_cur.label; }
    QString tags() const { return m_cur.tags; }
    QString about() const { return m_cur.about; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void lookup(const QString &title, const QString &artist, const QString &album, double lengthSec);
    Q_INVOKABLE void clear();

signals:
    void changed();

private:
    struct Info { QString year, country, label, tags, about; };
    QNetworkReply *get(const QUrl &url);
    void finish();

    QNetworkAccessManager m_nam;
    QHash<QString, Info> m_cache;
    Info m_cur;
    QString m_key;
    quint64 m_gen = 0;
    int m_pending = 0;
    bool m_busy = false;
};
