import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The card's background. type: 0 none (the widget's own panel setting), 1 color, 2 art backdrop (blurred and dimmed),
// 3 glass (a frosted pane over the blurred art), 4 liquid glass (the art through a lens that follows the pointer),
// 5 atmosphere (the cover's colors bleeding in from the corners), 6 solid. Plus film grain, an inner shadow and a
// light edge.
Item {
    id: root
    property int type: 0
    property url source
    property var coverColors: []      // colors of the cover
    property color accent: "#6a8cff"
    property color tint: "#cc1c2030"
    property int blur: 40             // 0..100
    property int dim: 35              // 0..100
    property int radius: 14
    property int grain: 0             // 0..100
    property bool shadow: false
    property bool edge: true
    property bool calm: false
    visible: type !== 0

    function pal(i, fallback) { return root.coverColors && root.coverColors.length > i ? root.coverColors[i] : fallback }

    Image {
        id: art
        source: root.source
        visible: false
        anchors.fill: parent
        sourceSize: Qt.size(512, 512)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { id: shapeMask; anchors.fill: parent; radius: root.radius; visible: false; layer.enabled: true }

    // a color wash for when there is no art
    readonly property bool haveArt: art.status === Image.Ready

    // 1: color, 6: solid
    Rectangle {
        anchors.fill: parent; radius: root.radius
        visible: root.type === 1 || root.type === 6
        color: root.type === 6 ? Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 1) : root.tint
    }

    // 2 and 3: the art, blurred, dimmed
    MultiEffect {
        anchors.fill: parent
        visible: (root.type === 2 || root.type === 3) && root.haveArt
        source: art
        maskEnabled: true; maskSource: shapeMask
        blurEnabled: true; blurMax: 64
        blur: root.type === 3 ? Math.max(0.7, root.blur / 100) : root.blur / 100
        brightness: -root.dim / 160
        saturation: root.type === 3 ? -0.15 : 0
    }
    Rectangle {
        anchors.fill: parent; radius: root.radius
        visible: (root.type === 2 || root.type === 3) && !root.haveArt
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(root.accent, 1.6) }
            GradientStop { position: 1; color: Qt.darker(root.accent, 3.2) }
        }
    }
    Rectangle {      // the dimming, and for glass a pale pane with a light top edge
        anchors.fill: parent; radius: root.radius
        visible: root.type === 2 || root.type === 3
        color: root.type === 3 ? "#26ffffff" : Qt.rgba(0, 0, 0, root.dim / 160)
        gradient: root.type === 3 ? glassGrad : null
    }
    Gradient { id: glassGrad
        GradientStop { position: 0; color: "#40ffffff" }
        GradientStop { position: 0.5; color: "#14ffffff" }
        GradientStop { position: 1; color: "#22ffffff" }
    }

    // 4: liquid glass (a shader)
    MouseArea {
        id: look
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        property point at: Qt.point(0.5, 0.35)
        onPositionChanged: (m) => at = Qt.point(m.x / width, m.y / height)
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.type === 4 && root.haveArt
        property variant src: ShaderEffectSource { sourceItem: art; live: false; hideSource: false }
        property real time: root.clock
        property real aspect: width / Math.max(1, height)
        property real dim: root.dim / 160
        property point pointer: look.at
        property real radius: root.radius / Math.max(1, height)
        property real lens: look.containsMouse ? 1 : 0.35
        fragmentShader: "liquid.frag.qsb"
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: shapeMask }
    }
    Rectangle {
        anchors.fill: parent; radius: root.radius
        visible: root.type === 4 && !root.haveArt
        color: Qt.darker(root.accent, 2.6)
    }
    property real clock: 0
    NumberAnimation on clock { from: 0; to: 1000; duration: 1000000; loops: Animation.Infinite; running: root.type === 4 && !root.calm && root.visible }

    // 5: atmosphere
    Rectangle { anchors.fill: parent; radius: root.radius; visible: root.type === 5; color: "#101218" }
    Shape {
        anchors.fill: parent
        visible: root.type === 5
        layer.enabled: true; layer.samples: 4
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 0; centerY: 0; centerRadius: Math.max(root.width, root.height) * 0.9; focalX: 0; focalY: 0
                GradientStop { position: 0; color: Qt.alpha(root.pal(0, root.accent), 0.75) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 } PathLine { x: root.width; y: root.height } PathLine { x: 0; y: root.height }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width; centerY: root.height; centerRadius: Math.max(root.width, root.height) * 0.9; focalX: root.width; focalY: root.height
                GradientStop { position: 0; color: Qt.alpha(root.pal(1, Qt.lighter(root.accent, 1.3)), 0.65) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 } PathLine { x: root.width; y: root.height } PathLine { x: 0; y: root.height }
        }
    }

    // inner shadow along the bottom, and a light edge
    Rectangle {
        anchors.fill: parent; radius: root.radius; visible: root.shadow
        gradient: Gradient {
            GradientStop { position: 0.55; color: "#00000000" }
            GradientStop { position: 1; color: "#66000000" }
        }
    }
    Rectangle {
        anchors.fill: parent; radius: root.radius; visible: root.edge
        color: "transparent"; border.width: 1; border.color: "#2effffff"
    }

    // film grain
    ShaderEffect {
        anchors.fill: parent
        visible: root.grain > 0
        property real amount: root.grain / 100
        property size size: Qt.size(width, height)
        fragmentShader: "grain.frag.qsb"
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: shapeMask }
    }
}
