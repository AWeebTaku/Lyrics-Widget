import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-font"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Layout")
        icon: "preferences-desktop-theme-global"
        source: "configLayout.qml"
    }
    ConfigCategory {
        name: i18n("Behavior")
        icon: "preferences-desktop-notification"
        source: "configContent.qml"
    }
    ConfigCategory {
        name: i18n("Sources")
        icon: "preferences-system-users"
        source: "configAccounts.qml"
    }
    ConfigCategory {
        name: i18n("Lyrics library")
        icon: "document-edit"
        source: "configLibrary.qml"
    }
}
