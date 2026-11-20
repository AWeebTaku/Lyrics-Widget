#include "WindowPlacer.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QFile>
#include <QTimer>
#include <QUrl>

namespace {
const QString kService = QStringLiteral("org.kde.KWin");
}

void WindowPlacer::center(const QString &scriptUrl)
{
    const QUrl url(scriptUrl);
    const QString file = url.isLocalFile() ? url.toLocalFile() : scriptUrl;
    auto bus = QDBusConnection::sessionBus();
    if (!QFile::exists(file) || !bus.isConnected() || !bus.interface()->isServiceRegistered(kService))
        return;   // not KWin: leave the window where it opened

    const QString name = QStringLiteral("lyricwidget-center-%1").arg(++m_count);
    QDBusMessage load = QDBusMessage::createMethodCall(kService, QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"),
                                                       QStringLiteral("loadScript"));
    load << file << name;
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(load), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, name, bus](QDBusPendingCallWatcher *w) mutable {
        const QDBusPendingReply<int> id = *w;
        w->deleteLater();
        if (!id.isValid() || id.value() < 0)
            return;
        bus.asyncCall(QDBusMessage::createMethodCall(kService, QStringLiteral("/Scripting/Script%1").arg(id.value()),
                                                     QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run")));
        QTimer::singleShot(500, this, [name, bus]() mutable {   // it has run: take it out again
            QDBusMessage unload = QDBusMessage::createMethodCall(kService, QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"),
                                                                 QStringLiteral("unloadScript"));
            unload << name;
            bus.asyncCall(unload);
        });
    });
}
