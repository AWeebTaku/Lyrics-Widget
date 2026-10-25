import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Lyrics")
        icon: "preferences-desktop-font"
        source: "configLyrics.qml"
    }
    ConfigCategory {
        name: i18n("Layout")
        icon: "preferences-desktop-theme-global"
        source: "configLayout.qml"
    }
    ConfigCategory {
        name: i18n("Visualizer style")
        icon: "preferences-desktop-color"
        source: "audioviz/configVisualizer.qml"
        visible: Plasmoid.configuration.showVisualizer
    }
    ConfigCategory {
        name: i18n("Audio input (CAVA)")
        icon: "audio-input-microphone"
        source: "audioviz/configCava.qml"
        visible: Plasmoid.configuration.showVisualizer
    }
    ConfigCategory {
        name: i18n("Sources")
        icon: "preferences-system-users"
        source: "configAccounts.qml"
    }
}
