import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import "../card/layouts.js" as Layouts

// Edit a layout: every part of it (the background, the cover, the title, the buttons, the seek bar, the clock, the lyrics, the
// visualizer, the corner buttons and the sync row) can be turned off, moved, resized and made see-through. The edits belong to
// the layout being edited, are stored in cfg_layoutEdits (JSON text) and are differences from where the layout puts the part.
ColumnLayout {
    id: ed
    required property var kcm
    property int mode: kcm.cfg_layoutMode ?? 2
    readonly property var layoutIds: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    readonly property var list: Layouts.partsFor(mode)
    spacing: Kirigami.Units.largeSpacing

    function edit(id, field, value) { kcm.cfg_layoutEdits = Layouts.setEdit(kcm.cfg_layoutEdits, mode, id, field, value) }
    function layoutName(m) {
        if (m === 0) return i18n("No card (lyrics and visualizer)")
        const x = Layouts.modes.find(q => q.id === m)
        return x ? x.name : String(m)
    }

    RowLayout {
        QQC2.Label { text: i18n("Layout to edit"); Layout.preferredWidth: Kirigami.Units.gridUnit * T.labelUnits }
        QQC2.ComboBox {
            implicitContentWidthPolicy: QQC2.ComboBox.WidestText
            model: ed.layoutIds.map(m => ed.layoutName(m) + (m === (ed.kcm.cfg_layoutMode ?? 2) ? i18n("  (the one in use)") : ""))
            // set once the model exists (a ComboBox starts at its first entry when the model arrives)
            Component.onCompleted: currentIndex = Math.max(0, ed.layoutIds.indexOf(ed.mode))
            onActivated: ed.mode = ed.layoutIds[currentIndex]
        }
    }
    QQC2.Label {
        text: i18n("Moves and sizes are in pixels.")
        opacity: T.muted; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 36
    }

    // quick choices: everything on, everything off, or one part on and the rest off
    function setAllShow(onlyId) {
        let j = kcm.cfg_layoutEdits
        for (const p of list) {
            const hide = onlyId === "none" ? true : onlyId === "all" ? false : p.id !== onlyId
            const base = !!Layouts.layout(mode, Layouts.naturalSize(mode)[0], Layouts.naturalSize(mode)[1], 96, 14, {})[p.key]
            j = Layouts.setEdit(j, mode, p.id, "show", hide ? false : (base || p.flag ? undefined : true))
        }
        kcm.cfg_layoutEdits = j
    }
    RowLayout {
        spacing: Kirigami.Units.smallSpacing
        QQC2.Label { text: i18n("Quick choices"); Layout.preferredWidth: Kirigami.Units.gridUnit * T.labelUnits }
        QQC2.Button { text: i18n("Show everything"); onClicked: ed.setAllShow("all") }
        QQC2.Button { text: i18n("Hide everything"); onClicked: ed.setAllShow("none") }
    }

    Repeater {
        model: ed.list
        Rectangle {
            id: box
            required property var modelData
            readonly property var e: Layouts.getEdit(ed.kcm.cfg_layoutEdits, ed.mode, modelData.id)
            readonly property var n: Layouts.naturalSize(ed.mode)
            readonly property var rect: modelData.key ? Layouts.layout(ed.mode, n[0], n[1], 96, 14, { edits: ed.kcm.cfg_layoutEdits })[modelData.key] : null
            // a part the layout leaves out starts off; it can be turned on (the corner buttons, say)
            readonly property bool hasBase: modelData.flag || !!Layouts.layout(ed.mode, n[0], n[1], 96, 14, {})[modelData.key]
            readonly property bool on: e.show === false ? false : (hasBase || e.show === true)
            Layout.fillWidth: true
            implicitHeight: inner.implicitHeight + 2 * Kirigami.Units.smallSpacing
            radius: T.radius
            color: Qt.alpha(Kirigami.Theme.textColor, on ? T.plate : 0)
            border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)

            ColumnLayout {
                id: inner
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    QQC2.Switch {
                        checked: box.on
                        onToggled: ed.edit(box.modelData.id, "show", checked ? (box.hasBase ? undefined : true) : false)
                    }
                    QQC2.Label { text: box.modelData.name; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    QQC2.Button { text: i18n("Only this"); flat: true; font: Kirigami.Theme.smallFont; onClicked: ed.setAllShow(box.modelData.id)
                                  QQC2.ToolTip.text: i18n("Show this part and hide all the others"); QQC2.ToolTip.visible: hovered }
                    QQC2.Label {
                        visible: box.on && !!box.rect
                        text: box.rect ? i18n("now at %1, %2 · %3 × %4", box.rect.x, box.rect.y, box.rect.w, box.rect.h) : ""
                        opacity: T.muted; font: Kirigami.Theme.smallFont
                    }
                }
                GridLayout {
                    visible: box.on && !box.modelData.flag
                    enabled: box.on
                    columns: 4
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.leftMargin: Kirigami.Units.gridUnit * 2.5
                    QQC2.Label { text: i18n("Right (px)"); opacity: T.muted }
                    QQC2.SpinBox { from: -3000; to: 3000; stepSize: 2; editable: true; value: box.e.dx ?? 0; onValueModified: ed.edit(box.modelData.id, "dx", value) }
                    QQC2.Label { text: i18n("Down (px)"); opacity: T.muted }
                    QQC2.SpinBox { from: -3000; to: 3000; stepSize: 2; editable: true; value: box.e.dy ?? 0; onValueModified: ed.edit(box.modelData.id, "dy", value) }
                    QQC2.Label { visible: box.modelData.size; text: i18n("Wider (px)"); opacity: T.muted }
                    QQC2.SpinBox { visible: box.modelData.size; from: -3000; to: 3000; stepSize: 2; editable: true; value: box.e.dw ?? 0; onValueModified: ed.edit(box.modelData.id, "dw", value) }
                    QQC2.Label { visible: box.modelData.size; text: i18n("Taller (px)"); opacity: T.muted }
                    QQC2.SpinBox { visible: box.modelData.size; from: -3000; to: 3000; stepSize: 2; editable: true; value: box.e.dh ?? 0; onValueModified: ed.edit(box.modelData.id, "dh", value) }
                    QQC2.Label { visible: box.modelData.opacity; text: i18n("Opacity (%)"); opacity: T.muted }
                    QQC2.SpinBox { visible: box.modelData.opacity; from: 0; to: 100; stepSize: 5; editable: true; value: box.e.opacity ?? 100; onValueModified: ed.edit(box.modelData.id, "opacity", value) }
                    QQC2.Label { visible: !!box.modelData.text; text: i18n("Title size (px)"); opacity: T.muted }
                    QQC2.SpinBox {
                        visible: !!box.modelData.text
                        from: 0; to: 96; editable: true; value: box.e.size ?? 0
                        textFromValue: v => v === 0 ? i18n("As set") : String(v)
                        onValueModified: ed.edit(box.modelData.id, "size", value)
                    }
                    QQC2.Button {
                        text: i18n("Reset")
                        icon.name: "edit-undo"
                        Layout.columnSpan: 4
                        enabled: Object.keys(box.e).length > 0
                        onClicked: { for (const f of ["show", "dx", "dy", "dw", "dh", "opacity", "size"]) ed.edit(box.modelData.id, f, undefined) }
                    }
                }
            }
        }
    }
    RowLayout {
        QQC2.Button { text: i18n("Reset this layout"); icon.name: "edit-undo"; onClicked: ed.kcm.cfg_layoutEdits = Layouts.resetEdits(ed.kcm.cfg_layoutEdits, ed.mode) }
        QQC2.Button { text: i18n("Reset every layout"); onClicked: ed.kcm.cfg_layoutEdits = "{}" }
    }
}
