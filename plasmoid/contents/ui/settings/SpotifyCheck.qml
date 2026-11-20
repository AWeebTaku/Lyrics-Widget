import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.lyricwidget

// Test the connection to the Spotify app's debug port.
RowLayout {
    id: row
    required property var kcm
    SpotifyApp { id: spotify }
    QQC2.Button { text: i18n("Test the connection"); icon.name: "network-connect"; onClicked: { spotify.debugPort = row.kcm.cfg_spotifyDebugPort; spotify.probe() } }
    QQC2.Label { text: spotify.appStatus; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 24 }
}
