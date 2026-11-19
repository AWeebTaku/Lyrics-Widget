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
    readonly property int mode: forceCard ? (s.layoutMode ?? 2) : Layouts.effectiveMode(s)
    readonly property var natural: Layouts.naturalSize(mode)
    // the preview is drawn at the layout's own size (so it looks as it will), scaled down to fit when it is wider
    readonly property real scaleFit: Math.min(1, width / natural[0])
    implicitHeight: natural[1] * scaleFit + 8

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

    Item {
        id: stage
        width: root.natural[0]; height: root.natural[1]
        scale: root.scaleFit
        transformOrigin: Item.TopLeft
        clip: true

        Rectangle { anchors.fill: parent; radius: 6; gradient: Gradient { GradientStop { position: 0; color: "#2f4a78" } GradientStop { position: 1; color: "#7a4a6a" } } }   // a stand-in wallpaper
        CardSurface {
            anchors.fill: parent
            type: root.s.cardSurface ?? 0
            source: sample.artUrl
            coverColors: ["#ff7a59", "#7a3fb0"]
            accent: root.accent
            tint: root.s.panelColor ?? "#a0101018"
            blur: root.s.surfaceBlur ?? 40; dim: root.s.surfaceDim ?? 35; radius: root.s.panelRadius ?? 20
            grain: root.s.surfaceGrain ?? 0; shadow: root.s.surfaceShadow ?? false; edge: root.s.surfaceEdge ?? true
        }
        VizPreview {
            readonly property var g: Layouts.layout(root.mode, stage.width, stage.height, root.s.artSize ?? 96, 14, { posterLines: root.s.posterLines, posterClock: root.s.posterClock, orbitCenter: root.s.orbitCenter })
            visible: root.viz.showVisualizer || g.vizForced
            color: "transparent"
            x: g.vizFill ? 0 : g.vizRect ? g.vizRect.x : 0
            y: g.vizFill ? 0 : g.vizRect ? g.vizRect.y : stage.height * 0.4
            width: g.vizFill ? stage.width : g.vizRect ? g.vizRect.w : stage.width
            height: g.vizFill ? stage.height : g.vizRect ? g.vizRect.h : stage.height * 0.6
            s: Object.assign({}, root.viz, g.orbit ? { visualizerStyle: 16 } : {})
            showToggle: false      // the card preview is one still picture
            opacity: (root.mode === 8 && root.s.posterVizBehind ? (root.s.posterVizOpacity ?? 60) / 100 : 1)
        }
        CardLayout {
            id: card
            anchors.fill: parent
            cfg: root.s
            mode: root.mode
            player: sample
            accent: root.accent
            systemAccent: root.systemAccent
            coverColors: ["#ff7a59", "#7a3fb0"]
            textColor: "white"
            dimColor: "#b0ffffff"
            beat: 0.2
            previewMode: true
            calm: true
        }
        // the lyrics, where the layout leaves room for them
        Text {
            visible: card.lyricsRect !== null && card.lyricsRect.h > 20
            x: card.lyricsRect ? card.lyricsRect.x : 0
            y: card.lyricsRect ? card.lyricsRect.y : 0
            width: card.lyricsRect ? card.lyricsRect.w : 0
            height: card.lyricsRect ? card.lyricsRect.h : 0
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: "A line of the lyrics"
            color: "white"; font.pixelSize: 18; elide: Text.ElideRight
        }
    }
}
