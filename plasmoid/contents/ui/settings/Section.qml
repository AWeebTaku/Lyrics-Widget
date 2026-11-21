import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "model.js" as Model
import "tokens.js" as T

// A group of settings: a title with a line of what it is for, then the rows. It opens and closes; while searching it shows what
// matches. Groups are told apart by a hairline, not boxed.
Item {
    id: card
    required property var section
    required property var kcm
    property bool first: false
    property string query: ""
    readonly property bool plain: section.plain === true      // the page's only group: no heading, never folded
    property bool open: plain || section.open === true
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
    implicitHeight: col.implicitHeight

    Rectangle {     // the hairline between groups
        visible: !card.first
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)
    }
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: card.first ? 0 : Kirigami.Units.largeSpacing }
        spacing: Kirigami.Units.largeSpacing

        // ---- the heading
        Item {
            visible: !card.plain
            Layout.fillWidth: true
            implicitHeight: card.plain ? 0 : head.implicitHeight + Kirigami.Units.smallSpacing
            Rectangle {
                anchors.fill: parent
                radius: T.radiusSmall
                color: Qt.alpha(Kirigami.Theme.textColor, T.plateHover)
                visible: headHover.hovered
            }
            HoverHandler { id: headHover }
            TapHandler { onTapped: card.open = !card.open }
            RowLayout {
                id: head
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: card.open || card.searching ? "arrow-down" : "arrow-right"
                    implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    QQC2.Label { text: card.section.title; font.weight: Font.DemiBold; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * T.sectionScale) }
                    QQC2.Label { text: card.section.desc ?? ""; visible: text !== ""; opacity: T.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                 font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * T.smallScale) }
                }
                QQC2.ToolButton {
                    visible: (card.open || card.searching) && card.resettable
                    icon.name: "edit-undo"
                    text: i18n("Reset")
                    display: QQC2.AbstractButton.TextBesideIcon
                    QQC2.ToolTip.text: i18n("Put every setting in this group back to its default")
                    QQC2.ToolTip.visible: hovered
                    onClicked: card.reset()
                }
            }
        }
        // ---- the rows
        Loader {
            active: card.open || card.searching
            visible: active
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing
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
