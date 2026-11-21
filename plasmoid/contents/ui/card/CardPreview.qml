import QtQuick
import "layouts.js" as Layouts
import "../viz"

// A live preview of the card in the settings: a sample song, the chosen layout, surface, cover, text, buttons and seek bar,
// with a made-up visualizer behind. `s` holds the settings in force (the saved ones with the page's unsaved changes on
// top); `viz` the saved visualizer settings.
Item {
    id: root
    property var s: ({})
    property var viz: ({})
    property color accent: "#e0875a"
    property color systemAccent: "#3daee9"
    // the Card page previews the arrangement chosen even while the card is off; the gallery shows what a look really does
    property bool forceCard: false
    property bool listening: false       // the visualizer in the preview draws the sound playing now (the pill)
    property bool still: false
    // With the pill on, the preview takes everything it can from the song playing now: title, artist, cover, cover colors,
    // position, controls state, the current lyric line, and the sound for the visualizer. `live` is the widget's controller.
    property var live: null
    readonly property bool useLive: listening && !!live && live.hasPlayer
    readonly property var player: useLive ? live : sample
    readonly property var coverCols: useLive && live.palette.length > 0 ? live.palette : ["#ff7a59", "#7a3fb0"]
    readonly property string lyricLine: useLive && live.lines.length > 0 ? (live.lines[Math.max(0, live.currentIndex)] ?? "") : "A line of the lyrics"
    readonly property int mode: forceCard ? (s.layoutMode ?? 2) : Layouts.effectiveMode(s)
    readonly property var natural: Layouts.naturalSize(mode)
    // the preview is drawn at the layout's own size (so it looks as it will), scaled down to fit when it is wider
    readonly property real scaleFit: Math.min(1, width / natural[0])
    implicitHeight: natural[1] * scaleFit + 8
    // the layout with the user's edits: the background and the visualizer follow them, like in the widget
    readonly property var g: Layouts.layout(mode, natural[0], natural[1], s.artSize ?? 96, 14, {
        posterLines: s.posterLines, posterClock: s.posterClock, orbitCenter: s.orbitCenter, edits: s.layoutEdits,
        viz: { widthPct: s.vizWidthPct ?? 100, heightPct: s.vizHeightPct ?? 60, hAlign: s.vizHAlign ?? 1, vAlign: s.vizVAlign ?? 2, offX: s.vizOffsetX ?? 0, offY: s.vizOffsetY ?? 0 } })

    QtObject {
        id: sample
        property string title: "Sample Song"
        property string artist: "The Preview"
        property string album: "Demo"
        property string artUrl: Qt.resolvedUrl("sample-cover.svg")
        property string thumbUrl: ""
        property string playerName: "Preview"
        property int playerCount: 1
        property real lengthSec: 214
        property bool playing: true
        property bool hasPlayer: true
        property real volume: 0.7
        property bool shuffle: false
        property string loopStatus: "None"
        property var chapters: [{ start: 0, title: "Intro" }, { start: 64, title: "Verse" }, { start: 131, title: "Bridge" }]
        property real clock: 82
        signal trackInfoChanged()
        function positionSec() { return clock }
        function playPause() { playing = !playing }
        function nextTrack() {}
        function previousTrack() {}
        function seekToSec(x) { clock = x }
        function seekBySec(d) { clock = Math.max(0, clock + d) }
        function cyclePlayer() {}
    }
    // the song plays: the seek bar and the clock move, and the layout's own animations run (unless motion is reduced)
    Timer {
        interval: 200; repeat: true
        running: root.visible && !root.still && !root.useLive
        onTriggered: sample.clock = (sample.clock + 0.2) % sample.lengthSec
    }

    Item {
        id: stage
        width: root.natural[0]; height: root.natural[1]
        scale: root.scaleFit
        transformOrigin: Item.TopLeft
        clip: true

        Rectangle { anchors.fill: parent; radius: 6; gradient: Gradient { GradientStop { position: 0; color: "#2f4a78" } GradientStop { position: 1; color: "#7a4a6a" } } }   // a stand-in wallpaper
        CardSurface {
            x: root.g.surface ? root.g.surface.x : 0; y: root.g.surface ? root.g.surface.y : 0
            width: root.g.surface ? root.g.surface.w : 0; height: root.g.surface ? root.g.surface.h : 0
            visible: root.g.surface !== null
            opacity: root.g.opacity.surface ?? 1
            type: root.s.cardSurface ?? 0
            source: root.player.artUrl
            coverColors: root.coverCols
            accent: root.accent
            tint: root.s.panelColor ?? "#a0101018"
            blur: root.s.surfaceBlur ?? 40; dim: root.s.surfaceDim ?? 35; radius: root.s.panelRadius ?? 20
            grain: root.s.surfaceGrain ?? 0; shadow: root.s.surfaceShadow ?? false; edge: root.s.surfaceEdge ?? true
        }
        VizPreview {
            id: cardViz
            animate: !root.still
            still: root.still
            visible: (root.viz.showVisualizer || root.g.vizForced) && root.g.vizPlace !== null
            color: "transparent"
            showListen: false
            listening: root.listening
            x: root.g.vizPlace ? root.g.vizPlace.x : 0
            y: root.g.vizPlace ? root.g.vizPlace.y : 0
            width: root.g.vizPlace ? root.g.vizPlace.w : 0
            height: root.g.vizPlace ? root.g.vizPlace.h : 0
            s: Object.assign({}, root.viz, root.g.orbit ? { visualizerStyle: 16 } : {})
            opacity: (root.mode === 8 && root.s.posterVizBehind ? (root.s.posterVizOpacity ?? 60) / 100 : 1) * (root.g.opacity.viz ?? 1)
        }
        CardLayout {
            id: card
            anchors.fill: parent
            cfg: root.s
            mode: root.mode
            player: root.player
            accent: root.accent
            systemAccent: root.systemAccent
            coverColors: root.coverCols
            textColor: "white"
            dimColor: "#b0ffffff"
            beat: 0.2
            previewMode: true
            calm: root.still
        }
        // the lyrics, where the layout leaves room for them
        Text {
            visible: card.lyricsRect !== null && card.lyricsRect.h > 20
            x: card.lyricsRect ? card.lyricsRect.x : 0
            y: card.lyricsRect ? card.lyricsRect.y : 0
            width: card.lyricsRect ? card.lyricsRect.w : 0
            height: card.lyricsRect ? card.lyricsRect.h : 0
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: root.lyricLine
            color: "white"; font.pixelSize: 18; elide: Text.ElideRight
        }
    }
    ListenPill {
        visible: !root.still
        anchors { right: parent.right; top: parent.top; margins: 6 }
        idleText: qsTr("Listen to my music")
        activeText: qsTr("Listening: stop")
        active: root.listening
        failed: !!cardViz.cava && cardViz.cava.hasError
        onToggled: root.listening = !root.listening
    }
}
