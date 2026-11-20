import QtQuick

// Loads a visualizer the user wrote as a QML file and hands it the music's levels. The file is run as it is: it is not
// sandboxed, so only use files you trust (the setting says so). The item it makes is given whichever of these
// properties it declares: values, peaks, bass, mid, high, beat, colors (and it should fill its parent).
Item {
    id: root
    property string file: ""
    property var values: []
    property var peaks: []
    property real bass: 0
    property real mid: 0
    property real high: 0
    property real beat: 0
    property var colors: []

    Loader {
        anchors.fill: parent
        active: root.file !== ""
        source: root.file !== "" ? "file://" + root.file : ""
        onLoaded: {
            for (const k of ["values", "peaks", "bass", "mid", "high", "beat", "colors"])
                if (k in item)
                    item[k] = Qt.binding(() => root[k])
        }
    }
}
