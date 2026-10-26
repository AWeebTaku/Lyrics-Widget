#pragma once
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTimer>
#include <QVariantMap>

// One MPRIS player on the session bus. Tracks metadata + play state and
// interpolates the playback position locally (no polling).
class MprisPlayer : public QObject
{
    Q_OBJECT
public:
    MprisPlayer(const QString &service, QObject *parent);

    const QString &service() const { return m_service; }
    const QString &title() const { return m_title; }
    const QString &artist() const { return m_artist; }
    const QString &album() const { return m_album; }
    const QString &url() const { return m_url; }
    const QString &artUrl() const { return m_artUrl; }
    qint64 lengthUs() const { return m_lengthUs; }
    bool playing() const { return m_playing; }
    qint64 positionUs() const;
    // While on (and playing), the real position is compared with the interpolated one twice a second: some
    // players (Spotify's own slider) do not announce every seek, which would leave the lyrics behind.
    void setWatchPosition(bool on);

signals:
    void metadataChanged();
    void stateChanged();
    void positionChanged(); // position re-synced from the player (seek / refetch)

private slots:
    void onPropertiesChanged(const QString &iface, const QVariantMap &changed,
                             const QStringList &invalidated);
    void onSeeked(qlonglong positionUs);

private:
    void refresh();
    void fetchPosition();
    void checkPosition();
    void updateWatch();
    void applyProps(const QVariantMap &props);

    QString m_service, m_title, m_artist, m_album, m_url, m_artUrl;
    qint64 m_lengthUs = 0;
    bool m_playing = false;
    qint64 m_basePosUs = 0;
    QElapsedTimer m_clock;
    QTimer m_posCheck;
    bool m_watch = false;
};

// Discovers Spotify / Chrome MPRIS players and elects the "active" one.
class PlayerWatcher : public QObject
{
    Q_OBJECT
public:
    explicit PlayerWatcher(QObject *parent = nullptr);
    void start();
    MprisPlayer *active() const { return m_active; }
    void setWatchPosition(bool on); // see MprisPlayer::setWatchPosition
    // Off (default): Spotify and Chrome-family browsers, the latter only on the allowed websites.
    // On: every MPRIS player on the bus counts (VLC, mpv, Strawberry...).
    void setAnyPlayer(bool on);
    void setSites(const QStringList &hosts); // websites that count as music in a browser

signals:
    void trackChanged();  // active player switched, or its track changed
    void timingChanged(); // play/pause/seek on the active player

private slots:
    void onOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);

private:
    bool isPlayerService(const QString &name) const;
    void rescan();
    bool eligible(const MprisPlayer *p) const;
    void add(const QString &name);
    void remove(const QString &name);
    void elect();

    QHash<QString, MprisPlayer *> m_players;
    QPointer<MprisPlayer> m_active;
    QPointer<MprisPlayer> m_lastStarted;
    bool m_watchPosition = false;
    bool m_any = false;
    QStringList m_sites;
};
