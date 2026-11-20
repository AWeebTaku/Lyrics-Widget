import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import "../audioviz/code/globals.js" as Globals
import "../audioviz/code/utils.js" as Utils

// How the visualizer is colored, stored as one JSON text (the visualizer draws from it as it is): a single color, a theme
// color, a list blended into a gradient, random colors, or a range of hues.
// spec: "bar" | "fill" | "inactive" picks the defaults the missing fields come from.
ColumnLayout {
    id: spec
    property string value: "{}"
    property string kind: "bar"
    signal edited(string json)

    readonly property var base: kind === "fill" ? Globals.baseWaveFillColors : kind === "inactive" ? Globals.baseInactiveBlockColors : Globals.baseBarColors
    // the stored text, completed with the defaults
    readonly property var cfg: {
        let parsed = {}
        try { parsed = JSON.parse(value || "{}") } catch (e) { parsed = {} }
        return Utils.mergeConfigs(base, parsed)
    }
    function put(field, v) {
        const c = JSON.parse(JSON.stringify(cfg))
        c[field] = v
        spec.edited(JSON.stringify(c))
    }
    readonly property var sourceTypes: [0, 1, 2, 3, 7]

    spacing: Kirigami.Units.smallSpacing

    QQC2.ComboBox {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        model: [i18n("One color"), i18n("A color of the Plasma theme"), i18n("A list of colors, blended"), i18n("Random colors"), i18n("A range of hues")]
        currentIndex: Math.max(0, spec.sourceTypes.indexOf(spec.cfg.sourceType))
        onActivated: spec.put("sourceType", spec.sourceTypes[currentIndex])
    }

    // one color
    ColorSwatch {
        visible: spec.cfg.sourceType === 0
        value: spec.cfg.custom
        onPicked: v => spec.put("custom", v)
    }
    // a theme color
    RowLayout {
        visible: spec.cfg.sourceType === 1
        readonly property var names: ["highlightColor", "textColor", "backgroundColor", "highlightedTextColor", "activeTextColor", "linkColor", "positiveTextColor", "neutralTextColor", "negativeTextColor"]
        readonly property var sets: ["Window", "View", "Button", "Selection"]
        QQC2.ComboBox {
            model: [i18n("Accent"), i18n("Text"), i18n("Background"), i18n("Text on the accent"), i18n("Active text"), i18n("Link"), i18n("Positive"), i18n("Neutral"), i18n("Negative")]
            currentIndex: Math.max(0, parent.names.indexOf(spec.cfg.systemColor))
            onActivated: spec.put("systemColor", parent.names[currentIndex])
        }
        QQC2.ComboBox {
            model: [i18n("of the window"), i18n("of views"), i18n("of buttons"), i18n("of selections")]
            currentIndex: Math.max(0, parent.sets.indexOf(spec.cfg.systemColorSet))
            onActivated: spec.put("systemColorSet", parent.sets[currentIndex])
        }
    }
    // a list of colors
    Flow {
        visible: spec.cfg.sourceType === 2
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 30
        spacing: Kirigami.Units.smallSpacing
        Repeater {
            model: spec.cfg.list
            Rectangle {
                id: chip
                required property string modelData
                required property int index
                width: Kirigami.Units.gridUnit * 2; height: width
                radius: T.radiusSmall
                color: modelData
                border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
                TapHandler { onTapped: pop.open() }
                QQC2.Popup {
                    id: pop
                    padding: Kirigami.Units.smallSpacing
                    ColumnLayout {
                        ColorSwatch { value: chip.modelData; onPicked: v => { const l = spec.cfg.list.slice(); l[chip.index] = v; spec.put("list", l) } }
                        QQC2.Button { text: i18n("Remove this color"); icon.name: "list-remove"; enabled: spec.cfg.list.length > 2
                            onClicked: { const l = spec.cfg.list.slice(); l.splice(chip.index, 1); spec.put("list", l); pop.close() } }
                    }
                }
            }
        }
        QQC2.Button {
            icon.name: "list-add"; text: i18n("Add")
            enabled: spec.cfg.list.length < 16
            onClicked: spec.put("list", spec.cfg.list.concat([spec.cfg.list[spec.cfg.list.length - 1] ?? "#ffffff"]))
        }
    }
    // a range of hues
    RowLayout {
        visible: spec.cfg.sourceType === 7
        QQC2.Label { text: i18n("From") }
        QQC2.SpinBox { from: 0; to: 360; value: spec.cfg.hueStart; onValueModified: spec.put("hueStart", value) }
        QQC2.Label { text: i18n("to") }
        QQC2.SpinBox { from: 0; to: 360; value: spec.cfg.hueEnd; onValueModified: spec.put("hueEnd", value) }
        QQC2.Label { text: i18n("degrees") }
    }
    Rectangle {
        visible: spec.cfg.sourceType === 7
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16; Layout.preferredHeight: 8; radius: 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.hsla(spec.cfg.hueStart / 360, 0.8, 0.55, 1) }
            GradientStop { position: 1.00; color: Qt.hsla(spec.cfg.hueEnd / 360, 0.8, 0.55, 1) }
        }
    }
    // how a list or a range is laid out
    RowLayout {
        visible: spec.cfg.sourceType > 1
        QQC2.ComboBox {
            model: [i18n("Across"), i18n("Up and down")]
            currentIndex: spec.cfg.colorsOrientation
            onActivated: spec.put("colorsOrientation", currentIndex)
        }
        QQC2.CheckBox { text: i18n("Reverse"); visible: spec.cfg.sourceType === 2; checked: spec.cfg.reverseList; onToggled: spec.put("reverseList", checked) }
        QQC2.CheckBox { text: i18n("Smooth blend"); visible: spec.cfg.sourceType === 2; checked: spec.cfg.smoothGradient; onToggled: spec.put("smoothGradient", checked) }
    }
    RowLayout {
        QQC2.Label { text: i18n("Opacity") }
        QQC2.SpinBox {
            from: 0; to: 100; value: Math.round(spec.cfg.alpha * 100)
            textFromValue: v => v + "%"
            onValueModified: spec.put("alpha", value / 100)
        }
    }
}
