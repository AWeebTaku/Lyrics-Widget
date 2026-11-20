import QtQuick

// A visualizer in a dozen lines: one bar per band, the bars swell with the beat. It is handed `values` (0..100 for each
// bar), `peaks`, `bass`, `mid`, `high`, `beat` (0..1) and `colors` (the bar colors) by the widget.
Item {
    property var values: []
    property var peaks: []
    property real bass: 0
    property real beat: 0
    property var colors: []

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: parent.parent.values.length
            Rectangle {
                required property int index
                width: Math.max(1, (parent.width - (parent.parent.values.length - 1) * 2) / parent.parent.values.length)
                height: Math.max(2, parent.height * (parent.parent.values[index] / 100) * (1 + 0.25 * parent.parent.beat))
                anchors.bottom: parent.bottom
                radius: width / 2
                color: parent.parent.colors.length ? parent.parent.colors[index % parent.parent.colors.length] : "white"
            }
        }
    }
}
