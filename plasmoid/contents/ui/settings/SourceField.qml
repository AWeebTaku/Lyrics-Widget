import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import "../audioviz/components"

// The audio capture source: type a name, or press the button to see what is available. The list is only fetched when asked
// for (starting the command engine is slow, and most people never change this).
ColumnLayout {
    id: src
    property string value: ""
    property var names: []
    property bool listing: false
    signal picked(string v)
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        QQC2.TextField {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            text: src.value
            placeholderText: i18n("auto")
            onEditingFinished: src.picked(text)
        }
        QQC2.Button {
            text: src.listing ? i18n("Hide the list") : i18n("Choose from the list…")
            icon.name: src.listing ? "arrow-up" : "arrow-down"
            onClicked: { src.listing = !src.listing; if (src.listing && src.names.length === 0) cmd.run("pactl list sources short && pactl list sinks short") }
        }
        QQC2.Button { text: i18n("Auto"); enabled: src.value !== ""; onClicked: src.picked("") }
    }
    Rectangle {
        visible: src.listing
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 36
        implicitHeight: Kirigami.Units.gridUnit * 9
        radius: T.radius
        color: Qt.alpha(Kirigami.Theme.textColor, T.plate)
        border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)
        QQC2.Label { visible: src.names.length === 0; anchors.centerIn: parent; text: i18n("Looking…"); opacity: T.muted }
        ListView {
            anchors.fill: parent; anchors.margins: 4
            clip: true
            model: src.names
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: QQC2.ItemDelegate {
                required property string modelData
                width: ListView.view.width
                text: modelData
                font: Kirigami.Theme.smallFont
                onClicked: src.picked(modelData)
            }
        }
    }
    RunCommand {
        id: cmd
        onExited: (c, exitCode, exitStatus, stdout) => {
            if (exitCode !== 0 || !stdout) return
            const l = stdout.trim().split("\n").map(x => x.split(/\t+/)[1]).filter(x => !!x)
            src.names = ["auto"].concat(l)
        }
    }
}
