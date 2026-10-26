import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts

// Swatch button. The colour dialog is created only when clicked: building native dialogs
// while the settings window opens is expensive and runs on plasmashell's UI thread.
RowLayout {
    id: field
    property string value: "#ffffff"
    property bool alpha: false // transparency allowed: shadow, highlight and background; text colors are always solid

    QQC2.Button {
        implicitWidth: 80
        onClicked: loader.active = true
        contentItem: Rectangle {
            radius: 3
            color: field.value
            border.color: "#80808080"
        }
    }
    QQC2.Label { text: field.value; opacity: 0.7 }

    Loader {
        id: loader
        active: false
        sourceComponent: ColorDialog {
            selectedColor: field.value
            options: field.alpha ? ColorDialog.ShowAlphaChannel : 0
            onAccepted: { field.value = (field.alpha ? selectedColor : Qt.rgba(selectedColor.r, selectedColor.g, selectedColor.b, 1)).toString(); loader.active = false }
            onRejected: loader.active = false
            Component.onCompleted: open()
        }
    }
}
