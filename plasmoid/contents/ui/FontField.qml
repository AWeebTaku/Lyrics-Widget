import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts

// Font name box + picker. Typing works too (any installed family). No font list is built until
// "Choose…" is clicked.
RowLayout {
    id: field
    property alias value: input.text

    QQC2.TextField {
        id: input
        Layout.preferredWidth: 220
        placeholderText: i18n("System default")
    }
    QQC2.Button {
        text: i18n("Choose…")
        onClicked: loader.active = true
    }
    QQC2.Button {
        icon.name: "edit-clear"
        enabled: input.text !== ""
        onClicked: input.text = ""
    }

    Loader {
        id: loader
        active: false
        sourceComponent: FontDialog {
            onAccepted: { input.text = selectedFont.family; loader.active = false }
            onRejected: loader.active = false
            Component.onCompleted: open()
        }
    }
}
