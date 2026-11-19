import QtQuick

// The GPU styles (plasma, terrain, tunnel): a fragment shader, compiled to <name>.frag.qsb, driven by the music's levels
Item {
    id: root
    property real bass: 0
    property real mid: 0
    property real high: 0
    property string shaderName: "plasma"
    property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)   // eight band levels for the shaders that use them
    property vector4d bandsB: Qt.vector4d(0, 0, 0, 0)
    property bool still: false          // reduced motion: the field does not move
    property color colorA: "#ff8a5c"
    property color colorB: "#d6457f"
    property color colorC: "#6a2c91"

    property real clock: 0
    NumberAnimation on clock { from: 0; to: 1000; duration: 1000 * 1000; loops: Animation.Infinite; running: !root.still && root.visible }

    ShaderEffect {
        anchors.fill: parent
        property real time: root.clock
        property real bass: root.bass
        property real mid: root.mid
        property real high: root.high
        property vector4d bandsA: root.bandsA
        property vector4d bandsB: root.bandsB
        property color colA: root.colorA
        property color colB: root.colorB
        property color colC: root.colorC
        fragmentShader: root.shaderName + ".frag.qsb"
    }
}
