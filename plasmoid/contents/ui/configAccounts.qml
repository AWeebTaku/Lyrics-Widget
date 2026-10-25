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

    // Own instance: login happens here; the widget re-reads the saved tokens when it needs them.
    SpotifyAccount { id: spotify }
    BrowserSetup { id: setup }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Spotify app (no account needed)") }
        QQC2.CheckBox {
            id: appQueue
            Kirigami.FormData.label: i18n("Queue:")
            text: i18n("Read the queue from the running Spotify app")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Debug port:")
            enabled: appQueue.checked
            QQC2.SpinBox {
                from: 1024; to: 65535; editable: true
                value: cfg_spotifyDebugPort
                onValueModified: cfg_spotifyDebugPort = value
            }
            QQC2.Button {
                text: i18n("Test")
                onClicked: { spotify.setDebugPort(cfg_spotifyDebugPort); spotify.probe() }
            }
            QQC2.Label { text: spotify.appStatus; opacity: 0.8; wrapMode: Text.WordWrap; Layout.maximumWidth: Kirigami.Units.gridUnit * 18 }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Reads the upcoming songs, including shuffle order, straight from the Spotify app on this computer through its local developer port (the one Spicetify enables, 8088 by default). Nothing leaves your machine except the lyric lookups, and nothing is changed in Spotify.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Spotify account (alternative)") }
        QQC2.TextField {
            id: clientId
            Kirigami.FormData.label: i18n("Client ID:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            text: spotify.clientId
            enabled: !spotify.connected
            placeholderText: i18n("from developer.spotify.com/dashboard")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Account:")
            QQC2.Button {
                text: spotify.connected ? i18n("Disconnect") : i18n("Connect…")
                onClicked: spotify.connected ? spotify.logout() : spotify.login(clientId.text)
            }
            QQC2.Label { text: spotify.status; opacity: 0.8 }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Only needed if you do not use the app option above. One-time setup: create a free app at developer.spotify.com/dashboard, add the redirect URI http://127.0.0.1:8898/callback, and paste its Client ID here. Only the read-playback-state permission is requested; tokens are stored in a file only you can read.")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Look ahead:")
            enabled: spotify.connected || appQueue.checked || ytm.checked
            from: 0; to: 5
            value: cfg_prefetchCount
            textFromValue: v => v === 0 ? i18n("Off") : i18np("%1 song", "%1 songs", v)
            onValueModified: cfg_prefetchCount = value
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Limited to 5, one song at a time, to stay under the lyric providers' rate limits.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("YouTube Music (Chrome extension)") }
        QQC2.CheckBox {
            id: ytm
            Kirigami.FormData.label: i18n("Queue:")
            text: i18n("Receive the YouTube Music queue from the Chrome extension")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Port:")
            enabled: ytm.checked
            from: 1024; to: 65535; editable: true
            value: cfg_browserQueuePort
            onValueModified: cfg_browserQueuePort = value
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            text: i18n("Browsers do not let apps read their queue, so a tiny extension passes the YouTube Music 'Up next' list to this widget. Install it once in the browser you use for YouTube Music:")
        }
        Repeater {
            model: setup.browsers
            QQC2.Button {
                required property var modelData
                Kirigami.FormData.label: index === 0 ? i18n("Step 1:") : ""
                icon.name: "internet-web-browser"
                text: i18n("Open %1's extensions page", modelData.name)
                onClicked: setup.openExtensions(modelData.exec, modelData.scheme)
            }
        }
        QQC2.Label {
            visible: setup.browsers.length === 0
            Kirigami.FormData.label: i18n("Step 1:")
            text: i18n("No Chromium browser found. Open your browser's extensions page yourself.")
        }
        QQC2.Label {
            Kirigami.FormData.label: i18n("Step 2:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            text: i18n("Turn on \"Developer mode\" (top right of that page).")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Step 3:")
            QQC2.Label { text: i18n("Click \"Load unpacked\" and pick:") }
            QQC2.Button { text: i18n("Copy folder path"); icon.name: "edit-copy"; onClicked: setup.copyPath() }
            QQC2.Button { text: i18n("Show folder"); icon.name: "folder-open"; onClicked: setup.openFolder() }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: setup.extensionPath + "\n" + i18n("In the file dialog press Ctrl+L and paste the path. The widget only listens on this computer and only accepts the extension. If you change the port above, change PORT in the extension's background.js to match.")
        }

    }
}
