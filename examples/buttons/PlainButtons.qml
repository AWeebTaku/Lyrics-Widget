import QtQuick

// Playback buttons made of plain characters. The widget hands it `playing`, `accent` and `iconColor`; it calls
// previous(), toggle() and next() (and toggleShuffle() / cycleLoop() if you want those too).
Row {
    id: root
    property bool playing: false
    property color accent: "#6a8cff"
    property color iconColor: "white"
    signal previous()
    signal toggle()
    signal next()
    spacing: 18
    anchors.centerIn: parent

    component Glyph: Text {
        signal activated()
        color: ma.containsMouse ? root.accent : root.iconColor
        font.pixelSize: 22
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.activated() }
    }
    Glyph { text: "⏮"; onActivated: root.previous() }
    Glyph { text: root.playing ? "⏸" : "▶"; onActivated: root.toggle() }
    Glyph { text: "⏭"; onActivated: root.next() }
}
