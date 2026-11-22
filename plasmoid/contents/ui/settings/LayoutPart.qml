import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import "../card/layouts.js" as Layouts

// One part of the card (the background, the cover, the buttons...) in the layout in use: turn it on or off, and set its X, Y,
// Width and Height in pixels from the card's top left, and how see-through it is. It sits in the part's own group on the Card
// page, next to the part's other settings. The edits belong to the layout in use, are stored in cfg_layoutEdits (JSON text)
// and are differences from where the layout puts the part, so a part keeps its place relative to the layout when the card is
// resized.
ColumnLayout {
    id: ed
    required property var kcm
    required property string partId
    readonly property int mode: kcm.cfg_layoutMode ?? 2
    readonly property var part: Layouts.parts.find(p => p.id === partId)
    readonly property var n: Layouts.naturalSize(mode)
    readonly property var e: Layouts.getEdit(kcm.cfg_layoutEdits, mode, partId)
    readonly property var base: Layouts.baseRect(mode, partId)
    readonly property var rect: part.key ? Layouts.layout(mode, n[0], n[1], 96, 14, { edits: kcm.cfg_layoutEdits })[part.key] : null
    // a part the layout leaves out starts off; it can be turned on (the corner buttons, say)
    readonly property bool hasBase: !!part.flag || !!Layouts.layout(mode, n[0], n[1], 96, 14, {})[part.key]
    readonly property bool on: e.show === false ? false : (hasBase || e.show === true)
    spacing: Kirigami.Units.smallSpacing

    function edit(field, value) { kcm.cfg_layoutEdits = Layouts.setEdit(kcm.cfg_layoutEdits, mode, partId, field, value) }
    // absolute edits: the stored value is the difference from the layout's own place for the part
    function move(field, abs, from) { edit(field, abs - from) }

    // a number box in px (or another unit); `shown` is the value it follows (a plain `value:` binding stops following once typed in)
    component PxBox: QQC2.SpinBox {
        property real shown: 0
        property string unit: " px"
        Binding on value { value: shown }
        editable: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
        textFromValue: (v) => String(v) + unit
        valueFromText: (t) => { const n = parseInt(t); return isNaN(n) ? 0 : n }
    }
    component Cap: QQC2.Label {
        opacity: T.muted
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
    }

    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        QQC2.Switch {
            Binding on checked { value: ed.on }
            onToggled: ed.edit("show", checked ? (ed.hasBase ? undefined : true) : false)
        }
        QQC2.Label { text: ed.on ? i18n("Shown") : i18n("Hidden"); opacity: T.muted }
    }
    GridLayout {
        visible: ed.on && !ed.part.flag && !!ed.rect
        columns: 4
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Cap { text: i18n("X") }
        PxBox { from: -3000; to: 3000; shown: ed.rect ? ed.rect.x : 0
                onValueModified: ed.move("dx", value, ed.base ? ed.base.x : 0) }
        Cap { text: i18n("Y") }
        PxBox { from: -3000; to: 3000; shown: ed.rect ? ed.rect.y : 0
                onValueModified: ed.move("dy", value, ed.base ? ed.base.y : 0) }
        Cap { visible: ed.part.size; text: i18n("Width") }
        PxBox { visible: ed.part.size; from: 8; to: 6000; shown: ed.rect ? ed.rect.w : 0
                onValueModified: ed.move("dw", value, ed.base ? ed.base.w : 0) }
        Cap { visible: ed.part.size; text: i18n("Height") }
        PxBox { visible: ed.part.size; from: 8; to: 6000; shown: ed.rect ? ed.rect.h : 0
                onValueModified: ed.move("dh", value, ed.base ? ed.base.h : 0) }
        Cap { visible: ed.part.opacity; text: i18n("Opacity") }
        PxBox { visible: ed.part.opacity; unit: " %"; from: 0; to: 100; stepSize: 5; shown: ed.e.opacity ?? 100
                onValueModified: ed.edit("opacity", value) }
        QQC2.Button {
            text: i18n("Reset")
            icon.name: "edit-undo"
            Layout.columnSpan: 4
            enabled: Object.keys(ed.e).length > 0
            onClicked: { for (const f of ["show", "dx", "dy", "dw", "dh", "opacity"]) ed.edit(f, undefined) }
        }
    }
}
