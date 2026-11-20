import QtQuick

// A seek bar: a gradient fill that grows with the song, chapter ticks, and a click to jump. The widget hands it
// `position` and `length` (seconds), `playing`, `accent`, `textColor`, `beat` and `chapters` ([{start, title}]);
// it asks for a seek with seekTo(seconds) or seekBy(seconds).
Item {
    id: root
    property real position: 0
    property real length: 0
    property color accent: "#6a8cff"
    property color textColor: "white"
    property var chapters: []
    signal seekTo(real sec)

    readonly property real frac: length > 0 ? Math.min(1, position / length) : 0

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 8; radius: 4
        color: Qt.alpha(root.textColor, 0.2)
        Rectangle {
            width: parent.width * root.frac; height: parent.height; radius: 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.lighter(root.accent, 1.4) }
                GradientStop { position: 1; color: root.accent }
            }
        }
        Repeater {
            model: root.length > 0 ? root.chapters : []
            Rectangle { required property var modelData; x: track.width * modelData.start / root.length; width: 2; height: 14; y: -3; color: root.textColor; opacity: 0.6 }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: m => root.seekTo(m.x / width * root.length) }
}
