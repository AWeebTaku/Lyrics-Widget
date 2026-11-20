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
    QQC2.Button {
        text: i18n("Check the next songs")
        icon.name: "view-media-playlist"
        enabled: !!row.live
        Layout.alignment: Qt.AlignTop
        onClicked: row.live.checkQueue()
    }
    QQC2.Label {
        text: !row.live ? i18n("Open the widget's own settings window to check.")
            : row.live.queueStatus !== "" ? row.live.queueStatus : i18n("Uses the saved settings: press Apply first.")
        opacity: 0.8; wrapMode: Text.WordWrap
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 30
    }
}
