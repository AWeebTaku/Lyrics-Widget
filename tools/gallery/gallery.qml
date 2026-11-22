import QtQuick
import "file://@UI@"
import "file://@UI@/card"
import "file://@UI@/viz/presets.js" as Presets

// Draws one built-in look at a time with the widget's own card and visualizer code (tools/gallery/render.sh).
Item {
    id: top
    property int index: 0
    readonly property int count: Presets.builtin.length
    property var vizObj: ({})
    readonly property int shotW: pv.natural[0] + 8
    readonly property int shotH: pv.implicitHeight
    width: shotW; height: shotH

    function applyPreset() {
        // read the list by index here: a property bound to `index` has not updated yet when onIndexChanged runs (every picture
        // was the look before the one named)
        const preset = Presets.builtin[index]
        const d = Presets.defaults()
        for (const k in d) Cfg[k] = d[k]
        for (const k in preset.settings) Cfg[k] = preset.settings[k]
        for (const k in preset.shot) Cfg[k] = preset.shot[k]       // what the picture needs that the look leaves to the owner (lyrics off for the GPU looks)
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
        still: true            // one frame, the same every time: no motion, no listen pill
    }
}
