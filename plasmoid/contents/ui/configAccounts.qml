import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.lyricwidget

KCM.SimpleKCM {
    property int cfg_prefetchCount
    property int cfg_prefetchCountDefault
    property alias cfg_spotifyAppQueue: appQueue.checked
    property int cfg_spotifyDebugPort
    property bool cfg_spotifyAppQueueDefault
    property alias cfg_browserQueue: ytm.checked
    property int cfg_browserQueuePort
    property bool cfg_browserQueueDefault
    property int cfg_browserQueuePortDefault
    property int cfg_spotifyDebugPortDefault

    SpotifyApp { id: spotify }   // only for the Test button
    BrowserSetup { id: setup }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Spotify") }
        RowLayout {
            QQC2.CheckBox { id: appQueue; text: i18n("Get lyrics and the queue from the Spotify app") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Needs Spotify started with a debug port (Spicetify does this). It only reads; nothing in Spotify is changed.") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Port:")
            enabled: appQueue.checked
            QQC2.SpinBox {
                from: 1024; to: 65535; editable: true
                value: cfg_spotifyDebugPort
                onValueModified: cfg_spotifyDebugPort = value
            }
            QQC2.Button {
                text: i18n("Test")
                onClicked: { spotify.debugPort = cfg_spotifyDebugPort; spotify.probe() }
            }
            QQC2.Label { text: spotify.appStatus; opacity: 0.8; wrapMode: Text.WordWrap; Layout.maximumWidth: Kirigami.Units.gridUnit * 18 }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Next songs") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Prepare lyrics for:")
            enabled: appQueue.checked || ytm.checked
            from: 0; to: 5
            value: cfg_prefetchCount
            textFromValue: v => v === 0 ? i18n("Off") : i18np("%1 song", "%1 songs", v)
            onValueModified: cfg_prefetchCount = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("YouTube Music") }
        RowLayout {
            QQC2.CheckBox { id: ytm; text: i18n("Get the queue from YouTube Music") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("A small browser extension sends the queue to this widget. It only talks to this computer.") }
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Port:")
            enabled: ytm.checked
            from: 1024; to: 65535; editable: true
            value: cfg_browserQueuePort
            onValueModified: cfg_browserQueuePort = value
        }
        Repeater {
            model: setup.browsers
            QQC2.Button {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? i18n("Install extension:") : ""
                icon.name: "internet-web-browser"
                text: i18n("Open %1 extensions", modelData.name)
                onClicked: setup.openExtensions(modelData.exec, modelData.scheme)
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Then choose this folder:")
            QQC2.Button { text: i18n("Copy path"); icon.name: "edit-copy"; onClicked: setup.copyPath() }
            QQC2.Button { text: i18n("Show folder"); icon.name: "folder-open"; onClicked: setup.openFolder() }
            Kirigami.ContextualHelpButton { toolTipText: i18n("In the extensions page: turn on Developer mode, click Load unpacked, press Ctrl+L and paste the path.") }
        }
    }
}
