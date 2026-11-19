import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// The cover art in one of six shapes: sharp, rounded, squircle, circle, vinyl record, CD. Optional border, glow, tilt,
// reflection, gray while paused, a spin while playing (records and discs), a progress ring and a small pulse on the beat.
Item {
    id: root
    property url source
    property int shape: 1          // 0 sharp, 1 rounded, 2 squircle, 3 circle, 4 vinyl, 5 cd
    property int borderWidth: 0
    property color borderColor: "white"
    property int glow: 0           // 0..100
    property bool tilt: false
    property bool reflect: false
    property bool grey: false
    property bool spin: false
    property bool playing: false
    property real progress: -1     // 0..1 draws a ring round the cover; -1 = none
    property color accent: "#6a8cff"
    property real beat: 0
    property bool calm: false      // no pulse, no spin
    property bool wide: false      // a 4:3 picture for the flat shapes instead of a square
    property int fallback: 0       // with no picture: 0 a music note, 1 the song's first letter, 2 color only
    property string letter: ""     // the first letter, for fallback 1
    signal clicked()

    readonly property bool disc: shape >= 4
    onShapeChanged: if (shape < 4) turning.rotation = 0
    readonly property real face: reflect ? height * 0.8 : height      // the cover's own height
    readonly property real side: Math.min(width, face)                // covers are square
    readonly property real sideW: wide && shape < 3 ? Math.min(width, side * 4 / 3) : side   // ... or 4:3
    readonly property real corner: shape === 0 ? 0 : shape === 1 ? side * 0.14 : shape === 2 ? side * 0.3 : side / 2

    // ---- the picture, hidden; the shapes below use it. A wide picture (a video's 16:9 frame) is shown whole over a blurred copy of
    // itself instead of being cut down to its middle.
    Image { id: probe; source: root.source; visible: false; asynchronous: true; cache: true }   // only to learn the picture's shape
    readonly property real aspect: probe.status === Image.Ready && probe.implicitHeight > 0 ? probe.implicitWidth / probe.implicitHeight : 1
    readonly property bool letterbox: aspect > 1.35 && !(wide && shape < 3)
    Item {
        id: picture
        visible: false
        layer.enabled: true
        width: root.sideW; height: root.side
        Image {
            id: fillImg
            anchors.fill: parent
            source: root.letterbox ? root.source : ""
            visible: root.letterbox
            sourceSize: Qt.size(Math.ceil(root.sideW), Math.ceil(root.side))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: root.letterbox
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0; brightness: -0.25 }
        }
        Image {
            id: img
            anchors.fill: parent
            source: root.source
            sourceSize: Qt.size(Math.ceil(root.sideW * 2), Math.ceil(root.side * 2))
            fillMode: root.letterbox ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    Item {
        id: stage
        width: root.sideW; height: root.side
        x: (root.width - width) / 2
        y: 0
        scale: 1 + (root.calm ? 0 : root.beat * 0.045)
        transform: Rotation {
            origin.x: stage.width / 2; origin.y: stage.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.tilt ? 18 : 0
            Behavior on angle { NumberAnimation { duration: 250 } }
        }

        // glow: a blurred copy behind the cover
        MultiEffect {
            anchors.centerIn: parent
            width: parent.width * 1.12; height: parent.height * 1.12
            source: picture
            visible: root.glow > 0 && img.status === Image.Ready
            blurEnabled: true; blurMax: 48; blur: 1.0
            opacity: root.glow / 100
            saturation: 0.3
        }

        // what turns: the cover, or the record with it as its label
        Item {
            id: turning
            anchors.fill: parent
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 6000
                loops: Animation.Infinite
                running: root.disc && root.spin && !root.calm && root.playing   // a stopped record stays where it stopped
            }

            // the cover cut to its shape (not for a record, which shows it as a small label)
            Rectangle { id: maskRect; anchors.fill: parent; radius: root.corner; visible: false; layer.enabled: true }
            // a CD has a hole: a ring-shaped mask (two circles, odd-even fill)
            Shape {
                id: cdMask
                anchors.fill: parent; visible: false; layer.enabled: true
                ShapePath {
                    fillColor: "white"; strokeColor: "transparent"; fillRule: ShapePath.OddEvenFill
                    PathAngleArc { centerX: cdMask.width / 2; centerY: cdMask.height / 2; radiusX: cdMask.width / 2; radiusY: cdMask.height / 2; startAngle: 0; sweepAngle: 360 }
                    PathMove { x: cdMask.width / 2 + cdMask.width * 0.09; y: cdMask.height / 2 }
                    PathAngleArc { centerX: cdMask.width / 2; centerY: cdMask.height / 2; radiusX: cdMask.width * 0.09; radiusY: cdMask.height * 0.09; startAngle: 0; sweepAngle: 360 }
                }
            }
            Rectangle { id: labelMask; anchors.centerIn: parent; width: parent.width * 0.42; height: width; radius: width / 2; visible: false; layer.enabled: true }

            // no art: a plain tile with a music note
            Rectangle {
                anchors.fill: parent
                radius: root.corner
                visible: img.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(root.accent, 1.2) }
                    GradientStop { position: 1; color: Qt.darker(root.accent, 1.8) }
                }
                Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.45; height: width; source: "audio-x-generic"; color: "white"; opacity: 0.85; visible: root.fallback === 0 }
                Text { anchors.centerIn: parent; visible: root.fallback === 1; text: root.letter.slice(0, 1).toUpperCase(); color: "white"; opacity: 0.9
                       font.pixelSize: parent.height * 0.5; font.bold: true }
            }

            // the cover, for the flat shapes and the CD
            MultiEffect {
                anchors.fill: parent
                source: picture
                visible: img.status === Image.Ready && root.shape !== 4
                maskEnabled: true
                maskSource: root.shape === 5 ? cdMask : maskRect
                saturation: root.gray ? -1 : 0
                brightness: root.gray ? -0.15 : 0
            }
            // the record: black disc, grooves, the cover as the label, a spindle hole
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#101114"; visible: root.shape === 4 }
            Repeater {
                model: root.shape === 4 ? 5 : 0
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: root.side * (0.52 + index * 0.09); height: width; radius: width / 2
                    color: "transparent"; border.width: 1; border.color: "#22ffffff"
                }
            }
            MultiEffect {
                anchors.centerIn: parent
                width: parent.width * 0.42; height: width
                source: picture
                visible: img.status === Image.Ready && root.shape === 4
                maskEnabled: true; maskSource: labelMask
                saturation: root.gray ? -1 : 0
            }
            Rectangle { anchors.centerIn: parent; width: root.side * 0.04; height: width; radius: width / 2; color: "#202226"; visible: root.shape === 4 }
        }

        // border and, for a record, its light sheen (does not turn)
        Rectangle {
            anchors.fill: parent; radius: root.corner
            color: "transparent"; visible: root.borderWidth > 0
            border.width: root.borderWidth; border.color: root.borderColor
        }
        // the light on a disc (not turning): a soft bright band, cut to the circle
        Rectangle {
            id: sheenSrc
            anchors.fill: parent; visible: false; layer.enabled: true
            gradient: Gradient { orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#ffffffff" } GradientStop { position: 0.45; color: "#00ffffff" }
                GradientStop { position: 0.8; color: "#00ffffff" } GradientStop { position: 1.0; color: "#66ffffff" } }
        }
        MultiEffect {
            anchors.fill: parent; source: sheenSrc
            visible: root.disc
            maskEnabled: true; maskSource: maskRect
            opacity: root.shape === 4 ? 0.2 : 0.35
        }

        // progress ring
        Shape {
            anchors.fill: parent; anchors.margins: -5
            visible: root.progress >= 0
            ShapePath {
                strokeColor: "#33ffffff"; strokeWidth: 3; fillColor: "transparent"
                PathAngleArc { centerX: stage.width / 2 + 5; centerY: stage.height / 2 + 5; radiusX: stage.width / 2 + 2; radiusY: stage.height / 2 + 2; startAngle: -90; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: root.accent; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: stage.width / 2 + 5; centerY: stage.height / 2 + 5; radiusX: stage.width / 2 + 2; radiusY: stage.height / 2 + 2; startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, root.progress)) }
            }
        }
    }

    // reflection: the cover upside down below it, fading out
    Item {
        id: mirror
        visible: root.reflect && img.status === Image.Ready
        width: root.side; height: root.height - root.face
        x: (root.width - width) / 2
        y: root.face + 1
        clip: true
        MultiEffect {
            width: root.side; height: root.side
            source: stage
            opacity: 0.28
            transform: [Scale { yScale: -1; origin.y: root.side / 2 }, Translate { y: root.side - mirror.height + 0 }]
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.0) }
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.clicked(); cursorShape: Qt.PointingHandCursor }
}
