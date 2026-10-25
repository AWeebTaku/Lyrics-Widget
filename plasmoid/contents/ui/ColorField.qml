import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts

// Swatch button. The colour dialog is created only when clicked: building native dialogs
// while the settings window opens is expensive and runs on plasmashell's UI thread.
RowLayout {
    id: field
    property string value: "#ffffff"

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
            options: ColorDialog.ShowAlphaChannel
            onAccepted: { field.value = selectedColor.toString(); loader.active = false }
            onRejected: loader.active = false
            Component.onCompleted: open()
        }
    }
}
