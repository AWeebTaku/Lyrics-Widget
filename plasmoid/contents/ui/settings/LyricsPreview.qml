import QtQuick
import "../"
import "../viz"

// A live preview of the lyric text for the Lyrics page: a made-up song, the current line moving on every few seconds, drawn
// with the same text styling as the widget (StyledText) from the settings in force in `s` (the page's unsaved values).
Rectangle {
    id: root
    property var s: ({})
    property bool still: false
    readonly property var song: ["the harbour lamps are coming on", "we count the boats and let them go", "a radio down by the rail",
                                 "plays something soft and something slow"]
    property int at: 1
    // the pill: show the lyric lines of the song playing now (when the widget has them) instead of the made-up song
    property var live: null
    property bool mySong: false
    readonly property bool haveSong: !!live && live.lines.length > 0
    readonly property bool useSong: mySong && haveSong
    readonly property var lines: useSong ? live.lines : song
    readonly property int pos: useSong ? Math.max(0, live.currentIndex) : at
    // the styling StyledText reads, with the widget's defaults for anything the page has not loaded yet
    readonly property var cfg: fill({ currentWeight: 700, sideWeight: 400, fontFamily: "", fontItalic: false, fontUnderline: false,
        fontCaps: 0, letterSpacing: 0, shadowOn: false, shadowColor: "#80000000", shadowX: 1, shadowY: 1, shadowBlur: 0,
        outlineOn: false, outlineColor: "#000000", outlineWidth: 1, highlightOn: false, highlightColor: "#40ffffff",
        highlightPadX: 12, highlightPadY: 4, highlightRadius: 8 })
    function fill(d) { const o = Object.assign({}, d); for (const k in s) if (s[k] !== undefined) o[k] = s[k]; return o }
    readonly property int hAlign: [Text.AlignLeft, Text.AlignHCenter, Text.AlignRight][s.lyricsHAlign ?? 1] ?? Text.AlignHCenter
    readonly property bool neighbours: s.showNeighbours ?? true
    readonly property int mainPx: (s.mainSize ?? 0) > 0 ? s.mainSize : 24
    readonly property int sidePx: (s.sideSize ?? 0) > 0 ? s.sideSize : 17
    implicitHeight: Math.max(150, 3 * mainPx * 1.7 + 24)
    color: "#181c26"
    radius: 8
    clip: true

    Timer { interval: 2600; repeat: true; running: root.visible && !root.still && !root.useSong; onTriggered: root.at = (root.at + 1) % root.song.length }
    ListenPill {
        anchors { right: parent.right; top: parent.top; margins: 6 }
        idleText: qsTr("Listen to my music")
        activeText: qsTr("Listening: stop")
        active: root.mySong
        failed: root.mySong && !root.haveSong
        onToggled: root.mySong = !root.mySong
    }

    Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
        spacing: 6
        Repeater {
            model: root.neighbours ? 3 : 1
            StyledText {
                required property int index
                readonly property int offset: root.neighbours ? index - 1 : 0
                width: parent.width
                height: (isCurrent ? root.mainPx : root.sidePx) * 1.6
                cfg: root.cfg
                isCurrent: offset === 0
                text: root.lines[(root.pos + offset + root.lines.length) % root.lines.length]
                color: isCurrent ? (root.s.textColor ?? "#ffffff") : (root.s.dimColor ?? "#99ffffff")
                pixelSize: isCurrent ? root.mainPx : root.sidePx
                horizontalAlignment: root.hAlign
                verticalAlignment: Text.AlignVCenter
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
}
