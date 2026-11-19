import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.lyricwidget

// Installing the small browser extension that sends the YouTube Music queue to this widget.
ColumnLayout {
    id: col
    spacing: Kirigami.Units.smallSpacing
    BrowserSetup { id: setup }
    readonly property var chosen: setup.browsers[box.currentIndex] ?? null

    RowLayout {
        QQC2.ComboBox { id: box; textRole: "name"; model: setup.browsers; implicitContentWidthPolicy: QQC2.ComboBox.WidestText }
        QQC2.Button {
            text: i18n("Install the extension")
            icon.name: "internet-web-browser"
            enabled: !!col.chosen
            onClicked: { setup.openExtensions(col.chosen.exec, col.chosen.scheme); opened.visible = true }
        }
    }
    QQC2.Label {
        id: opened
        visible: false
        opacity: 0.8; wrapMode: Text.WordWrap
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 32
        text: i18n("If the browser did not open its extensions page, paste this into its address bar (it is on your clipboard): %1", col.chosen ? col.chosen.scheme + "://extensions" : "")
    }
    RowLayout {
        QQC2.Label { text: i18n("Then choose this folder:") }
        QQC2.Button { text: i18n("Copy the path"); icon.name: "edit-copy"; onClicked: setup.copyPath() }
        QQC2.Button { text: i18n("Show the folder"); icon.name: "folder-open"; onClicked: setup.openFolder() }
    }
    QQC2.Label {
        text: i18n("In the extensions page: turn on Developer mode, click Load unpacked, press Ctrl+L and paste the path.")
        opacity: 0.6; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 32
    }
}
