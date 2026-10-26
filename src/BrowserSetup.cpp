#include "BrowserSetup.h"

#include <QClipboard>
#include <QDesktopServices>
#include <QGuiApplication>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

QVariantList BrowserSetup::browsers() const
{
    struct B { const char *name, *scheme; QStringList bins; };
    static const QList<B> known = {
        {"Google Chrome", "chrome", {"google-chrome-stable", "google-chrome"}},
        {"Chromium", "chrome", {"chromium", "chromium-browser"}},
        {"Brave", "brave", {"brave", "brave-browser", "brave-browser-stable"}},
        {"Vivaldi", "vivaldi", {"vivaldi", "vivaldi-stable"}},
        {"Opera", "opera", {"opera"}},
        {"Microsoft Edge", "edge", {"microsoft-edge-stable", "microsoft-edge"}},
        {"Thorium", "chrome", {"thorium-browser"}},
        {"Ungoogled Chromium", "chrome", {"ungoogled-chromium"}},
    };
    QVariantList out;
    for (const B &b : known)
        for (const QString &bin : b.bins) {
            const QString path = QStandardPaths::findExecutable(bin);
            if (!path.isEmpty()) {
                out << QVariantMap{{"name", QString::fromLatin1(b.name)}, {"exec", path},
                                   {"scheme", QString::fromLatin1(b.scheme)}};
                break;
            }
        }
    return out;
}

QString BrowserSetup::extensionPath() const
{
    const QString p = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                             QStringLiteral("lyric-widget/extension"),
                                             QStandardPaths::LocateDirectory);
    return p.isEmpty() ? QStringLiteral("/usr/share/lyric-widget/extension") : p;
}

void BrowserSetup::openExtensions(const QString &exec, const QString &scheme) const
{
    // Browsers often ignore a chrome:// address given on the command line and just open: the address is also
    // put on the clipboard, to paste into the address bar
    const QString url = scheme + QStringLiteral("://extensions");
    QGuiApplication::clipboard()->setText(url);
    QProcess::startDetached(exec, {QStringLiteral("--new-tab"), url});
}

void BrowserSetup::openFolder() const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(extensionPath()));
}

void BrowserSetup::copyPath() const
{
    QGuiApplication::clipboard()->setText(extensionPath());
}
