import QtQuick
import "file://@UI@"
import "file://@UI@/card"
import "file://@UI@/viz/presets.js" as Presets

// Draws one built-in look at a time with the widget's own card and visualizer code (tools/gallery/render.sh).
Item {
    id: top
    property int index: 0
    readonly property int count: Presets.builtin.length
    readonly property var preset: Presets.builtin[index]
    property var vizObj: ({})
    readonly property int shotW: pv.natural[0] + 8
    readonly property int shotH: pv.implicitHeight
    width: shotW; height: shotH

    function applyPreset() {
        const d = Presets.defaults()
        for (const k in d) Cfg[k] = d[k]
        for (const k in preset.settings) Cfg[k] = preset.settings[k]
        Cfg.controlsShow = 2
        const o = {}
        for (const k in Presets.keys) o[k] = Cfg[k]
        vizObj = o
    }
    onIndexChanged: applyPreset()
    Component.onCompleted: applyPreset()

    Rectangle { anchors.fill: parent; color: "#0d1220" }
    CardPreview {
        id: pv
        x: 4; y: 4
        width: natural[0]
        s: Cfg
        viz: top.vizObj
        accent: "#e0875a"
    }
}
