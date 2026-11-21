import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Check that the next songs can be read, from the Spotify app and from the YouTube Music extension: one line for each says what
// worked and what to fix. It asks the widget itself (its saved settings), so it needs the widget's own settings window.
RowLayout {
    id: row
    readonly property var live: Window.window ? Window.window.live : null
    property bool browser: false          // test the browser extension link only, instead of the next songs from both sources
    QQC2.Button {
        text: row.browser ? i18n("Test the connection") : i18n("Check the next songs")
        icon.name: row.browser ? "network-connect" : "view-media-playlist"
        enabled: !!row.live
        Layout.alignment: Qt.AlignTop
        onClicked: row.browser ? row.live.checkBrowser() : row.live.checkQueue()
    }
    QQC2.Label {
        text: !row.live ? i18n("Open the widget's own settings window to check.")
            : (row.browser ? row.live.browserStatus : row.live.queueStatus) !== "" ? (row.browser ? row.live.browserStatus : row.live.queueStatus)
            : i18n("Uses the saved settings: press Apply first.")
        opacity: 0.8; wrapMode: Text.WordWrap
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 30
    }
}
