#include "PlayerWatcher.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QUrl>

namespace {
const QString kPrefix = QStringLiteral("org.mpris.MediaPlayer2.");
const QString kPath = QStringLiteral("/org/mpris/MediaPlayer2");
const QString kPlayerIface = QStringLiteral("org.mpris.MediaPlayer2.Player");
const QString kPropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

// Chrome's own MPRIS player reports a bare tab title ("Happier | YouTube Music"), no artist, no
// URL. plasma-browser-integration (the extension) reports real metadata plus the page URL, so
// it is preferred, and Chrome's own player is only used while the extension has nothing.
// Every tab with media shows up, so only these hosts count as "music".
// Add your own here (e.g. a self-hosted player).
const QStringList kAllowedChromeHosts = {
    QStringLiteral("music.youtube.com"),
    QStringLiteral("www.youtube.com"),
    QStringLiteral("youtube.com"),
    QStringLiteral("open.spotify.com"),
};

QStringList toStringList(const QVariant &v)
{
    if (v.canConvert<QDBusArgument>())
        return qdbus_cast<QStringList>(v.value<QDBusArgument>());
    return v.toStringList();
}

bool isBrowserIntegration(const QString &service)
{
    return service.mid(kPrefix.size()).startsWith(QLatin1String("plasma-browser-integration"));
}

bool isSpotify(const QString &service)
{
    const QString rest = service.mid(kPrefix.size());
    return rest == QLatin1String("spotify") || rest.startsWith(QLatin1String("spotify."));
}
} // namespace

// ---------------------------------------------------------------- MprisPlayer

MprisPlayer::MprisPlayer(const QString &service, QObject *parent)
    : QObject(parent), m_service(service)
{
    m_clock.start();
    auto bus = QDBusConnection::sessionBus();
    bus.connect(service, kPath, kPropsIface, QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    bus.connect(service, kPath, kPlayerIface, QStringLiteral("Seeked"), this,
                SLOT(onSeeked(qlonglong)));
    refresh();
}

qint64 MprisPlayer::positionUs() const
{
    return m_playing ? m_basePosUs + m_clock.nsecsElapsed() / 1000 : m_basePosUs;
}

void MprisPlayer::refresh()
{
    auto msg = QDBusMessage::createMethodCall(m_service, kPath, kPropsIface, QStringLiteral("GetAll"));
    msg << kPlayerIface;
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *watcher) {
        watcher->deleteLater();
        QDBusPendingReply<QVariantMap> reply = *watcher;
        if (!reply.isError())
            applyProps(reply.value());
    });
}

void MprisPlayer::fetchPosition()
{
    auto msg = QDBusMessage::createMethodCall(m_service, kPath, kPropsIface, QStringLiteral("Get"));
    msg << kPlayerIface << QStringLiteral("Position");
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *watcher) {
        watcher->deleteLater();
        QDBusPendingReply<QDBusVariant> reply = *watcher;
        if (reply.isError())
            return;
        m_basePosUs = reply.value().variant().toLongLong();
        m_clock.restart();
        emit positionChanged();
    });
}

void MprisPlayer::applyProps(const QVariantMap &p)
{
    bool metaChanged = false;
    bool stateFlipped = false;

    if (p.contains(QStringLiteral("Metadata"))) {
        const QVariant v = p.value(QStringLiteral("Metadata"));
        const QVariantMap md = v.canConvert<QDBusArgument>()
                                   ? qdbus_cast<QVariantMap>(v.value<QDBusArgument>())
                                   : v.toMap();
        const QString title = md.value(QStringLiteral("xesam:title")).toString();
        const QStringList artists = toStringList(md.value(QStringLiteral("xesam:artist")));
        const QString artist = artists.isEmpty() ? QString() : artists.first();
        const QString album = md.value(QStringLiteral("xesam:album")).toString();
        const QString url = md.value(QStringLiteral("xesam:url")).toString();
        const qint64 len = md.value(QStringLiteral("mpris:length")).toLongLong();

        const QString art = md.value(QStringLiteral("mpris:artUrl")).toString();
        if (art != m_artUrl) {
            m_artUrl = art;
            metaChanged = true;
        }
        if (title != m_title || artist != m_artist || album != m_album || len != m_lengthUs
            || url != m_url) {
            // A new song starts at 0. Until the real position arrives (an async D-Bus call), the old
            // song's position must not carry over, or the new lyrics show a line from the wrong place.
            if (title != m_title || url != m_url) {
                m_basePosUs = 0;
                m_clock.restart();
            }
            m_title = title; m_artist = artist; m_album = album; m_url = url; m_lengthUs = len;
            metaChanged = true;
        }
    }

    if (p.contains(QStringLiteral("PlaybackStatus"))) {
        const bool nowPlaying = p.value(QStringLiteral("PlaybackStatus")).toString()
                                == QLatin1String("Playing");
        if (nowPlaying != m_playing) {
            m_basePosUs = positionUs(); // freeze/rebase before flipping
            m_clock.restart();
            m_playing = nowPlaying;
            stateFlipped = true;
        }
    }

    if (p.contains(QStringLiteral("Position"))) {
        m_basePosUs = p.value(QStringLiteral("Position")).toLongLong();
        m_clock.restart();
    }

    if (metaChanged)
        emit metadataChanged();
    if (stateFlipped)
        emit stateChanged();
    if (metaChanged || stateFlipped)
        fetchPosition(); // authoritative position (a new track starts at ~0)
}

void MprisPlayer::onPropertiesChanged(const QString &iface, const QVariantMap &changed,
                                      const QStringList &)
{
    if (iface == kPlayerIface)
        applyProps(changed);
}

void MprisPlayer::onSeeked(qlonglong positionUs)
{
    m_basePosUs = positionUs;
    m_clock.restart();
    emit positionChanged();
}

// -------------------------------------------------------------- PlayerWatcher

PlayerWatcher::PlayerWatcher(QObject *parent) : QObject(parent) {}

bool PlayerWatcher::isPlayerService(const QString &name)
{
    if (!name.startsWith(kPrefix))
        return false;
    const QString rest = name.mid(kPrefix.size());
    return isSpotify(name) || isBrowserIntegration(name) || rest.startsWith(QLatin1String("chromium"))
           || rest.startsWith(QLatin1String("chrome"))
           || rest.startsWith(QLatin1String("google-chrome"));
}

bool PlayerWatcher::eligible(const MprisPlayer *p) const
{
    if (isSpotify(p->service()))
        return true;
    if (!isBrowserIntegration(p->service())) {
        for (const MprisPlayer *o : std::as_const(m_players))
            if (isBrowserIntegration(o->service()) && !o->title().isEmpty())
                return false; // the extension's richer metadata wins
        if (p->url().isEmpty())
            return true; // Chrome's own player never has a URL
    }
    return kAllowedChromeHosts.contains(QUrl(p->url()).host());
}

void PlayerWatcher::start()
{
    auto bus = QDBusConnection::sessionBus();
    auto *iface = bus.interface();
    if (!bus.isConnected() || !iface)
        return; // no session bus
    bus.connect(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
                QStringLiteral("org.freedesktop.DBus"), QStringLiteral("NameOwnerChanged"), this,
                SLOT(onOwnerChanged(QString, QString, QString)));
    const QStringList names = iface->registeredServiceNames().value();
    for (const QString &n : names)
        if (isPlayerService(n))
            add(n);
}

void PlayerWatcher::onOwnerChanged(const QString &name, const QString &oldOwner,
                                   const QString &newOwner)
{
    if (!isPlayerService(name))
        return;
    if (oldOwner.isEmpty() && !newOwner.isEmpty())
        add(name);
    else if (!oldOwner.isEmpty() && newOwner.isEmpty())
        remove(name);
}

void PlayerWatcher::add(const QString &name)
{
    if (m_players.contains(name))
        return;
    auto *p = new MprisPlayer(name, this);
    m_players.insert(name, p);

    connect(p, &MprisPlayer::metadataChanged, this, [this, p] {
        const auto prev = m_active;
        elect();
        if (m_active == p || m_active != prev)
            emit trackChanged();
    });
    connect(p, &MprisPlayer::stateChanged, this, [this, p] {
        const auto prev = m_active;
        if (p->playing())
            m_lastStarted = p;
        elect();
        if (m_active != prev)
            emit trackChanged();
        if (m_active == p || m_active != prev)
            emit timingChanged();
    });
    connect(p, &MprisPlayer::positionChanged, this, [this, p] {
        if (m_active == p)
            emit timingChanged();
    });
}

void PlayerWatcher::remove(const QString &name)
{
    MprisPlayer *p = m_players.take(name);
    if (!p)
        return;
    const auto prev = m_active;
    p->deleteLater();
    if (m_lastStarted == p) m_lastStarted = nullptr;
    if (m_active == p) m_active = nullptr;
    elect();
    if (m_active != prev) {
        emit trackChanged();
        emit timingChanged();
    }
}

void PlayerWatcher::elect()
{
    MprisPlayer *next = nullptr;
    if (m_lastStarted && m_lastStarted->playing() && eligible(m_lastStarted))
        next = m_lastStarted;
    if (!next) {
        for (MprisPlayer *p : std::as_const(m_players))
            if (p->playing() && eligible(p)) { next = p; break; }
    }
    if (!next && m_active && eligible(m_active))
        next = m_active; // keep showing the paused one
    if (!next) {
        for (MprisPlayer *p : std::as_const(m_players))
            if (eligible(p) && !p->title().isEmpty()) { next = p; break; }
    }
    m_active = next;
}
