import QtQuick

// A seek bar the user wrote as a QML file (off unless "Allow my own QML" is on; the file runs with no sandbox).
// The item the file makes is given whichever of these properties it declares: position, length (seconds), playing,
// accent, textColor, beat (0..1), chapters ([{start, title}]), labels (0 off, 1 elapsed/total, 2 elapsed/remaining).
// It asks for a seek by emitting seekTo(sec) or seekBy(seconds). It should fill its parent.
Item {
    id: root
    property string file: ""
    property real position: 0
    property real length: 0
    property bool playing: false
    property color accent: "#6a8cff"
    property color textColor: "white"
    property real beat: 0
    property var chapters: []
    property int labels: 1
    signal seekTo(real sec)
    signal seekBy(real sec)

    Loader {
        anchors.fill: parent
        active: root.file !== ""
        source: root.file !== "" ? "file://" + root.file : ""
        onLoaded: {
            for (const k of ["position", "length", "playing", "accent", "textColor", "beat", "chapters", "labels"])
                if (k in item)
                    item[k] = Qt.binding(() => root[k])
            if (item.seekTo) item.seekTo.connect(s => root.seekTo(s))
            if (item.seekBy) item.seekBy.connect(d => root.seekBy(d))
        }
    }
}
