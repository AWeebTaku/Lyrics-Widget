import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "tokens.js" as T
import "../card/layouts.js" as Layouts

// Edit a layout: every part of it (the background, the cover, the title, the buttons, the seek bar, the clock, the lyrics, the
// visualizer, the corner buttons and the sync row) can be turned off, moved, resized and made see-through. The page shows each
// part's X, Y, Width and Height in pixels on the card's own grid (snapped to the grid step). The edits belong to the layout
// being edited, are stored in cfg_layoutEdits (JSON text) and are differences from where the layout puts the part, so a part
// keeps its place relative to the layout when the card is resized.
ColumnLayout {
    id: ed
    required property var kcm
    readonly property int inUse: Plasmoid.configuration.layoutMode ?? 2      // chosen on the Card page
    property int mode: inUse
    readonly property var layoutIds: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    readonly property var list: Layouts.partsFor(mode)
    spacing: Kirigami.Units.largeSpacing
    property int snap: 4                       // the grid step in px: typed and stepped values land on multiples of it
    readonly property var snaps: [1, 2, 4, 8, 16]

    // a number box in px (or another unit) with the unit in the text, so no value is ambiguous
    component PxBox: QQC2.SpinBox {
        property string unit: " px"
        editable: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
        textFromValue: (v) => String(v) + unit
        valueFromText: (t) => { const n = parseInt(t); return isNaN(n) ? 0 : n }
    }
    // a small name above the unit for one number
    component Cap: QQC2.Label {
        opacity: T.muted
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
    }

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
            model: ed.layoutIds.map(m => ed.layoutName(m) + (m === ed.inUse ? i18n("  (the one in use)") : ""))
            // set once the model exists (a ComboBox starts at its first entry when the model arrives)
            Component.onCompleted: currentIndex = Math.max(0, ed.layoutIds.indexOf(ed.mode))
            onActivated: ed.mode = ed.layoutIds[currentIndex]
        }
    }
    RowLayout {
        QQC2.Label { text: i18n("Grid step"); Layout.preferredWidth: Kirigami.Units.gridUnit * T.labelUnits }
        QQC2.ComboBox {
            implicitContentWidthPolicy: QQC2.ComboBox.WidestText
            model: ed.snaps.map(v => v + " px")
            currentIndex: Math.max(0, ed.snaps.indexOf(ed.snap))
            onActivated: ed.snap = ed.snaps[currentIndex]
        }
    }
    QQC2.Label {
        text: i18n("Pixels from the card's top left. Values snap to the grid step.")
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
            readonly property var base: Layouts.baseRect(ed.mode, modelData.id)
            // absolute edits: the stored value is the difference from the layout's own place for the part
            function snapped(v) { return Math.round(v / ed.snap) * ed.snap }
            function move(field, abs, from) { ed.edit(modelData.id, field, snapped(abs) - from) }
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
                }
                GridLayout {
                    visible: box.on && !box.modelData.flag && !!box.rect
                    enabled: box.on
                    columns: 4
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.leftMargin: Kirigami.Units.gridUnit * 2.5
                    Cap { text: i18n("X") }
                    PxBox { from: -3000; to: 3000; stepSize: ed.snap; value: box.rect ? box.rect.x : 0
                            onValueModified: box.move("dx", value, box.base ? box.base.x : 0) }
                    Cap { text: i18n("Y") }
                    PxBox { from: -3000; to: 3000; stepSize: ed.snap; value: box.rect ? box.rect.y : 0
                            onValueModified: box.move("dy", value, box.base ? box.base.y : 0) }
                    Cap { visible: box.modelData.size; text: i18n("Width") }
                    PxBox { visible: box.modelData.size; from: 8; to: 6000; stepSize: ed.snap; value: box.rect ? box.rect.w : 0
                            onValueModified: box.move("dw", value, box.base ? box.base.w : 0) }
                    Cap { visible: box.modelData.size; text: i18n("Height") }
                    PxBox { visible: box.modelData.size; from: 8; to: 6000; stepSize: ed.snap; value: box.rect ? box.rect.h : 0
                            onValueModified: box.move("dh", value, box.base ? box.base.h : 0) }
                    Cap { visible: box.modelData.opacity; text: i18n("Opacity") }
                    PxBox { visible: box.modelData.opacity; unit: " %"; from: 0; to: 100; stepSize: 5; value: box.e.opacity ?? 100
                            onValueModified: ed.edit(box.modelData.id, "opacity", value) }
                    Cap { visible: !!box.modelData.text; text: i18n("Title size") }
                    PxBox {
                        visible: !!box.modelData.text
                        from: 0; to: 96; value: box.e.size ?? 0
                        textFromValue: (v) => v === 0 ? i18n("As set") : v + " px"
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
