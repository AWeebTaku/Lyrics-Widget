import QtQuick
import org.kde.plasma.configuration

// Settings, grouped by subject: the widget itself, the lyrics, the visualizer, the media card, where songs come from,
// and your own lyrics.
ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Lyrics")
        icon: "preferences-desktop-font"
        source: "configLyrics.qml"
    }
    ConfigCategory {
        name: i18n("Visualizer")
        icon: "multimedia-volume-control"
        source: "configVisualizer.qml"
    }
    ConfigCategory {
        name: i18n("Audio input")
        icon: "audio-input-microphone"
        source: "configAudio.qml"
    }
    ConfigCategory {
        name: i18n("Card")
        icon: "view-media-playlist"
        source: "configCard.qml"
    }
    ConfigCategory {
        name: i18n("Looks")
        icon: "preferences-desktop-theme"
        source: "configLooks.qml"
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
