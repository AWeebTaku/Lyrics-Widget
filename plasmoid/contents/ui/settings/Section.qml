import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "model.js" as Model

// A group of settings on a rounded card with a heading. It opens and closes; while searching it shows what matches.
Rectangle {
    id: card
    required property var section
    required property var kcm
    property string query: ""
    property bool open: section.open === true
    readonly property bool searching: query !== ""
    readonly property bool inPanel: (Plasmoid.location ?? 0) !== 0       // 0: floating, on the desktop
    readonly property bool titleHit: searching && section.title.toLowerCase().indexOf(query) >= 0

    function rowHit(r) {
        return ((r.label ?? "") + " " + (r.hint ?? "") + " " + (r.text ?? "")).toLowerCase().indexOf(query) >= 0
    }
    // a row is shown when it applies to the settings now, and (while searching) when it matches
    function shown(r) {
        if (r.panel && !inPanel) return false
        if (!Model.whenMet(r.when, k => kcm["cfg_" + k])) return false
        return !searching || titleHit || rowHit(r)
    }
    readonly property int count: section.rows.filter(r => shown(r)).length
    function reset() {
        for (const r of section.rows)
            for (const k of Model.rowKeys(r)) {
                const d = kcm["cfg_" + k + "Default"]
                if (d !== undefined) kcm["cfg_" + k] = d
            }
    }
    readonly property bool resettable: section.rows.some(r => Model.rowKeys(r).length > 0)

    visible: count > 0
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 2 * Kirigami.Units.largeSpacing
    radius: Kirigami.Units.gridUnit * 0.8
    color: Qt.alpha(Kirigami.Theme.textColor, 0.045)
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.09)

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing }
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: card.open || card.searching ? "arrow-down" : "arrow-right"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
                opacity: 0.7
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                QQC2.Label { text: card.section.title; font.weight: Font.DemiBold; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.15) }
                QQC2.Label { text: card.section.desc ?? ""; visible: text !== ""; opacity: 0.62; wrapMode: Text.WordWrap; Layout.fillWidth: true; font: Kirigami.Theme.smallFont }
            }
            QQC2.ToolButton {
                visible: (card.open || card.searching) && card.resettable
                icon.name: "edit-undo"
                text: i18n("Reset")
                display: QQC2.AbstractButton.TextBesideIcon
                font: Kirigami.Theme.smallFont
                QQC2.ToolTip.text: i18n("Put every setting in this group back to its default")
                QQC2.ToolTip.visible: hovered
                onClicked: card.reset()
            }
            TapHandler { onTapped: card.open = !card.open }
        }
        Loader {
            active: card.open || card.searching
            visible: active
            Layout.fillWidth: true
            sourceComponent: ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: card.section.rows
                    Field {
                        required property var modelData
                        row: modelData
                        kcm: card.kcm
                        visible: card.shown(modelData)
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
