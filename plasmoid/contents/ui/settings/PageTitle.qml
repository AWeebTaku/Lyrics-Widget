import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T

// The top of a settings page: the page's icon in the accent color, its name, and one line of what it is for.
RowLayout {
    id: head
    property string icon
    property string title
    property string subtitle
    spacing: Kirigami.Units.largeSpacing
    Kirigami.Icon {
        source: head.icon
        implicitWidth: Kirigami.Units.iconSizes.large
        implicitHeight: implicitWidth
        isMask: true
        color: Kirigami.Theme.highlightColor
        Layout.alignment: Qt.AlignTop
    }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        QQC2.Label { text: head.title; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * T.titleScale); font.weight: Font.Medium }
        QQC2.Label { text: head.subtitle; visible: text !== ""; opacity: T.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
