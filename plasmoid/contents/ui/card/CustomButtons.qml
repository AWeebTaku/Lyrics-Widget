import QtQuick

// Playback buttons the user wrote as a QML file (off unless "Allow my own QML" is on; no sandbox). The item is given
// whichever of these properties it declares: playing, shuffle, loop ("None", "Track", "Playlist"), accent, iconColor,
// showSkip, showShuffleRepeat; and it calls the signals previous(), toggle(), next(), toggleShuffle(), cycleLoop().
Item {
    id: root
    property string file: ""
    property bool playing: false
    property bool shuffle: false
    property string loop: "None"
    property color accent: "#6a8cff"
    property color iconColor: "white"
    property bool showSkip: true
    property bool showShuffleRepeat: false
    signal previous()
    signal toggle()
    signal next()
    signal toggleShuffle()
    signal cycleLoop()

    Loader {
        anchors.fill: parent
        active: root.file !== ""
        source: root.file !== "" ? "file://" + root.file : ""
        onLoaded: {
            for (const k of ["playing", "shuffle", "loop", "accent", "iconColor", "showSkip", "showShuffleRepeat"])
                if (k in item)
                    item[k] = Qt.binding(() => root[k])
            for (const s of ["previous", "toggle", "next", "toggleShuffle", "cycleLoop"])
                if (item[s] && item[s].connect)
                    item[s].connect(root[s])
        }
    }
}
