import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

// A color: a swatch that opens the color dialog, and the hex code to type or paste.
RowLayout {
    id: sw
    property string value: "#ffffff"
    property bool alpha: false
    signal picked(string v)
    spacing: Kirigami.Units.smallSpacing

    QQC2.Button {
        implicitWidth: Kirigami.Units.gridUnit * 3
        onClicked: dialog.active = true
        contentItem: Rectangle {
            radius: 4
            color: sw.value
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
        }
    }
    QQC2.TextField {
        id: hex
        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
        text: sw.value
        maximumLength: 9
        font.family: "monospace"
        validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{0,8}$/ }
        onEditingFinished: {
            if (/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text)) sw.picked(text.toLowerCase())
            else text = sw.value
        }
    }
    Loader {
        id: dialog
        active: false
        sourceComponent: ColorDialog {
            selectedColor: sw.value
            options: sw.alpha ? ColorDialog.ShowAlphaChannel : 0
            onAccepted: {
                const c = sw.alpha ? selectedColor : Qt.rgba(selectedColor.r, selectedColor.g, selectedColor.b, 1)
                sw.picked(c.toString())
                dialog.active = false
            }
            onRejected: dialog.active = false
            Component.onCompleted: open()
        }
    }
}
