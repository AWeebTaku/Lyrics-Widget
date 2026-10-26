import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.lyricwidget
import "audioviz"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground   // we draw our own panel
    // Size: 0 = free, 1 = fixed width/height from settings, 2 = full screen width (+ height)
    // (a fixed size of 0 means "as small as possible": 1 px; a free widget can be dragged down to 1 px)
    readonly property real wantW: cfg.sizeMode === 2 ? Screen.width : (cfg.sizeMode === 1 ? Math.max(1, cfg.widthPx) : 0)
    readonly property real wantH: cfg.sizeMode === 0 ? 0 : Math.max(1, cfg.heightPx)
    Layout.minimumWidth: wantW > 0 ? wantW : 1
    Layout.preferredWidth: wantW > 0 ? wantW : 760
    Layout.maximumWidth: wantW > 0 ? wantW : Number.POSITIVE_INFINITY
    Layout.minimumHeight: wantH > 0 ? wantH : 1
    Layout.preferredHeight: wantH > 0 ? wantH : 220
    Layout.maximumHeight: wantH > 0 ? wantH : Number.POSITIVE_INFINITY

    readonly property var cfg: Plasmoid.configuration

    // Fade out after the music has been paused for a while; any playback brings it back
    property bool faded: false
    Timer {
        interval: Math.max(1, root.cfg.fadeWhenPausedMin) * 60000
        running: root.cfg.fadeWhenPausedMin > 0 && !lyrics.playing && !lyrics.idle
        onTriggered: root.faded = true
    }
    Connections {
        target: lyrics
        function onPlayingChanged() { if (lyrics.playing) root.faded = false }
        function onIdleChanged() { if (!lyrics.idle) root.faded = false }
    }
    readonly property color curColor: cfg.tintFromArt && lyrics.accent.valid ? lyrics.accent : cfg.textColor

    // Windows on this screen: a full screen / maximized one suspends the whole widget
    TasksModel {
        id: windows
        screenGeometry: Plasmoid.containment.screenGeometry
    }
    readonly property bool suspended:
        (cfg.pauseOnFullScreenWindow && windows.fullScreenExists)
        || (cfg.pauseOnMaximizedWindow && windows.maximizedExists)

    LyricsController {
        id: lyrics
        suspended: root.suspended
        lyricsEnabled: root.cfg.showLyrics
        offsetMs: root.cfg.offsetMs
        prefetchCount: root.cfg.prefetchCount
        spotifyAppQueue: root.cfg.spotifyAppQueue
        spotifyDebugPort: root.cfg.spotifyDebugPort
        browserQueue: root.cfg.browserQueue
        browserQueuePort: root.cfg.browserQueuePort
    }


    // Romanization replaces the original line when there is one; otherwise the original shows.
    function lineAt(i) {
        const l = lyrics.lines
        if (i < 0 || i >= l.length)
            return ""
        const r = root.cfg.showRoman ? lyrics.roman[i] : ""
        const t = r || l[i]
        return t === "" ? "♪" : t
    }

    fullRepresentation: Item {
        id: view
        clip: true
        opacity: ((root.cfg.hideWhenNothingPlaying && lyrics.idle) || root.faded) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Rectangle {
            anchors.fill: parent
            visible: root.cfg.showPanel
            radius: root.cfg.panelRadius
            color: root.cfg.panelColor
        }

        // audio visualizer (Plasma Audio Visualizer's renderer + cava), behind the lyrics;
        // the Loader keeps cava off unless it is wanted and music is playing
        Loader {
            id: vizLoader
            active: root.cfg.showVisualizer && !lyrics.idle && lyrics.playing && !root.suspended
            source: "AudioViz.qml"
            onLoaded: item.tint = Qt.binding(() => root.cfg.tintFromArt && root.cfg.tintVisualizer && lyrics.accent.valid
                                                    ? lyrics.accent.toString() : "")
            // size as a share of the widget, placed on a 3x3 grid plus a pixel offset
            width: parent.width * root.cfg.vizWidthPct / 100
            height: parent.height * root.cfg.vizHeightPct / 100
            x: (root.cfg.vizHAlign === 0 ? 0 : root.cfg.vizHAlign === 2 ? parent.width - width : (parent.width - width) / 2)
               + root.cfg.vizOffsetX
            y: (root.cfg.vizVAlign === 0 ? 0 : root.cfg.vizVAlign === 2 ? parent.height - height : (parent.height - height) / 2)
               + root.cfg.vizOffsetY
        }

        // artist — title
        Text {
            visible: root.cfg.showHeader && lyrics.title !== ""
            anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: (lyrics.artist ? lyrics.artist + " — " + lyrics.title : lyrics.title)
                  + (lyrics.incomplete ? "   ⚠ lyrics incomplete" : "")
                  + (lyrics.estimatedLines > 0 ? "   ≈ " + lyrics.estimatedLines + " lines timed by estimate" : "")
                  + (root.cfg.showSyncControls && lyrics.gapSec !== 0 ? "   ⚠ version differs by " + (lyrics.gapSec > 0 ? "+" : "") + lyrics.gapSec + "s: use ± to sync" : "")
            color: root.cfg.dimColor
            font.family: root.cfg.fontFamily
            font.pixelSize: 13
        }

        // "Loading…", "No lyrics found", … when there are no lines
        Text {
            x: 20 + root.cfg.lyricsOffsetX
            y: root.cfg.lyricsOffsetY
            width: parent.width - 40
            height: parent.height
            visible: root.cfg.showLyrics && lyrics.lines.length === 0 && root.cfg.sideSize > 0
            horizontalAlignment: view.hAlign
            verticalAlignment: view.vAlign
            wrapMode: Text.WordWrap
            text: lyrics.status
            color: root.cfg.dimColor
            font.family: root.cfg.fontFamily
            font.pixelSize: Math.max(1, root.cfg.sideSize)
        }

        // where the lyrics sit in the panel: 3x3 grid (+ offsets); the same for all lyric text
        readonly property int hAlign: root.cfg.lyricsHAlign === 0 ? Text.AlignLeft
                                      : root.cfg.lyricsHAlign === 2 ? Text.AlignRight : Text.AlignHCenter
        readonly property int vAlign: root.cfg.lyricsVAlign === 0 ? Text.AlignTop
                                      : root.cfg.lyricsVAlign === 2 ? Text.AlignBottom : Text.AlignVCenter

        // word highlight: follows the player position frame by frame, only while a timed line plays
        property real kfrac: -1
        function fracAt(pts, t) {
            if (t <= pts[0][0])
                return pts[0][1]
            for (let i = 1; i < pts.length; ++i)
                if (t <= pts[i][0]) {
                    const a = pts[i - 1], b = pts[i]
                    return b[0] === a[0] ? b[1] : a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
                }
            return 1
        }
        readonly property bool hasWords: root.cfg.karaoke && lyrics.karaoke.length > 1
        onHasWordsChanged: kfrac = hasWords ? 0 : -1
        FrameAnimation {
            running: view.hasWords && lyrics.playing && !root.suspended && view.visible
            onTriggered: view.kfrac = view.fracAt(lyrics.karaoke, lyrics.linePosMs())
        }
        Connections {
            target: lyrics
            function onCurrentIndexChanged() { view.kfrac = view.hasWords ? 0 : -1 }
        }

        // synced: previous / current / next, with the line transition
        LyricStage {
            x: 20 + root.cfg.lyricsOffsetX
            y: root.cfg.lyricsOffsetY
            width: parent.width - 40
            height: parent.height
            hAlign: root.cfg.lyricsHAlign
            vAlign: root.cfg.lyricsVAlign
            visible: root.cfg.showLyrics && lyrics.synced
            cfg: root.cfg
            index: lyrics.currentIndex
            gapMs: lyrics.lineGapMs
            animate: root.cfg.animateLines
            curColor: root.curColor
            hidden: lyrics.lineHidden
            showSides: root.cfg.showNeighbours && (!root.cfg.autoCompact || view.height >= 150)
            karaokeFrac: view.kfrac
            id: stage
            prev: root.lineAt(lyrics.currentIndex - 1).replace(/\n/g, "  ·  ")
            cur: root.lineAt(lyrics.currentIndex)
            next: root.lineAt(lyrics.currentIndex + 1).replace(/\n/g, "  ·  ")
        }

        // unsynced fallback: static block
        Text {
            x: 30 + root.cfg.lyricsOffsetX
            y: 30 + root.cfg.lyricsOffsetY
            width: parent.width - 60
            height: parent.height - 60
            visible: root.cfg.showLyrics && lyrics.lines.length > 0 && !lyrics.synced && root.cfg.sideSize > 0
            horizontalAlignment: view.hAlign
            verticalAlignment: view.vAlign
            elide: Text.ElideRight
            clip: true
            text: lyrics.lines.map((l, i) => (root.cfg.showRoman && lyrics.roman[i]) || l).join("\n")
            color: root.cfg.textColor
            font.family: root.cfg.fontFamily
            font.pixelSize: Math.max(1, root.cfg.sideSize)
        }

        // Hover to nudge this song's timing (remembered per song): + = lyrics earlier, - = later.
        // Off by default; Settings -> Lyrics -> Timing.
        HoverHandler { id: hover }
        Row {
            id: nudgeRow
            visible: root.cfg.showSyncControls && hover.hovered && lyrics.synced
            anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
            spacing: 14
            Repeater {
                model: [
                    { label: "−1s", ms: -1000 }, { label: "−0.2s", ms: -200 },
                    { label: "reset", ms: 0 },
                    { label: "+0.2s", ms: 200 }, { label: "+1s", ms: 1000 }
                ]
                Text {
                    required property var modelData
                    text: modelData.ms === 0 ? "sync " + (lyrics.trackOffsetMs / 1000).toFixed(1) + "s ⟲" : modelData.label
                    color: root.cfg.dimColor
                    font.pixelSize: 13
                    MouseArea {
                        anchors { fill: parent; margins: -6 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lyrics.nudge(modelData.ms)
                    }
                }
            }
        }
    }
}
