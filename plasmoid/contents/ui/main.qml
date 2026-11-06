import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
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

    // One time for everything: after the music has been paused for this long the widget fades out, the lyrics stop
    // updating and the visualizer stops (it also hides after the same time of silence). Any playback brings it back.
    property bool faded: false
    Timer {
        interval: Math.max(1, root.cfg.hideAfterSec) * 1000
        running: root.cfg.hideAfterSec > 0 && !lyrics.playing && !lyrics.idle
        onTriggered: root.faded = true
    }
    Connections {
        target: root.cfg
        function onHideAfterSecChanged() { root.faded = false }
    }
    Connections {
        target: lyrics
        function onPlayingChanged() { if (lyrics.playing) root.faded = false }
        function onIdleChanged() { if (!lyrics.idle) root.faded = false }
    }
    // Colours of the album cover (when switched on): the main one for the current line, the second for the
    // other lines, all of them as a gradient in the visualizer
    readonly property bool tinted: cfg.tintFromArt && lyrics.palette.length > 0
    // A very dark cover color would make the text vanish on a dark desktop: lift it to half brightness
    function lift(c) {
        return c.hslLightness < 0.5 ? Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, 0.5, c.a) : c
    }
    readonly property color curColor: tinted ? lift(lyrics.palette[0]) : cfg.textColor
    // "One color" uses only the cover's main colour (current line and visualizer); the other lines keep their own
    readonly property bool multiColor: tinted && cfg.tintMode === 0 && lyrics.palette.length > 1
    readonly property color sideColor: multiColor ? Qt.alpha(lift(lyrics.palette[1]), 0.8) : cfg.dimColor

    // Windows on this screen: a full screen one suspends the whole widget; a maximized one only hides it (the song
    // and lyrics are still followed, so it fades back in on the right line) and stops the visualizer
    TasksModel {
        id: windows
        screenGeometry: Plasmoid.containment.screenGeometry
    }
    readonly property bool covered: cfg.pauseOnMaximizedWindow && windows.maximizedExists
    readonly property bool suspended: (cfg.pauseOnFullScreenWindow && windows.fullScreenExists) || faded

    LyricsController {
        id: lyrics
        suspended: root.suspended
        lyricsEnabled: root.cfg.showLyrics
        offsetMs: root.cfg.offsetMs
        prefetchCount: root.cfg.prefetchCount
        spotifyAppQueue: root.cfg.spotifyAppQueue
        spotifyDebugPort: root.cfg.spotifyDebugPort
        anyPlayer: root.cfg.anyPlayer
        allowedSites: root.cfg.allowedSites
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
        opacity: ((root.cfg.hideWhenNothingPlaying && lyrics.idle) || root.faded || root.covered) ? 0 : 1
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
            active: root.cfg.showVisualizer && !lyrics.idle && (lyrics.playing || root.cfg.hideAfterSec > 0) && !root.suspended && !root.covered
            source: "AudioViz.qml"
            onLoaded: { item.tintFlow = Qt.binding(() => root.cfg.vizColorFlow); item.tintColors = Qt.binding(() => !root.tinted ? [] : (root.multiColor ? lyrics.palette.map(c => c.toString()) : [lyrics.palette[0].toString()])) }
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
            color: root.sideColor
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
            // "No lyrics found" and the like fade away after a few seconds; "Loading…" stays until it is answered
            opacity: view.statusShown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
            horizontalAlignment: view.hAlign
            verticalAlignment: view.vAlign
            wrapMode: Text.WordWrap
            text: lyrics.status
            color: root.sideColor
            font.family: root.cfg.fontFamily
            font.pixelSize: Math.max(1, root.cfg.sideSize)
        }

        property bool statusShown: true
        function updateStatusTimer() {
            statusShown = true
            const s = lyrics.status
            if (s !== "" && !s.startsWith("Loading") && !s.startsWith("Finding") && !s.startsWith("Couldn't"))
                statusTimer.restart()
            else
                statusTimer.stop()
        }
        Timer { id: statusTimer; interval: 6000; onTriggered: view.statusShown = false }
        Connections { target: lyrics; function onStatusChanged() { view.updateStatusTimer() } }
        Component.onCompleted: updateStatusTimer()

        // where the lyrics sit in the panel: 3x3 grid (+ offsets); the same for all lyric text
        readonly property int hAlign: root.cfg.lyricsHAlign === 0 ? Text.AlignLeft
                                      : root.cfg.lyricsHAlign === 2 ? Text.AlignRight : Text.AlignHCenter
        readonly property int vAlign: root.cfg.lyricsVAlign === 0 ? Text.AlignTop
                                      : root.cfg.lyricsVAlign === 2 ? Text.AlignBottom : Text.AlignVCenter

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
            curColors: root.multiColor ? lyrics.palette.slice(0, 4).map(c => root.lift(c)) : []
            curFlow: root.cfg.lyricColorFlow
            sideColor: root.sideColor
            hidden: lyrics.lineHidden
            showSides: root.cfg.showNeighbours && view.height >= 150   // no room for them in a small widget
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
        // Off by default; Settings -> Behavior -> Lyrics tab.
        HoverHandler { id: hover }
        // Hover buttons, top right: look for other lyrics (saved to the library) and open the library
        Column {
            visible: root.cfg.hoverButtons && hover.hovered && !lyrics.idle
            anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 8 }
            spacing: 4
            Repeater {
                model: [
                    { icon: "view-refresh", tip: "Look for other lyrics", act: 0 },
                    { icon: "document-edit", tip: "Lyrics library", act: 1 }
                ]
                Item {
                    required property var modelData
                    width: 26; height: 26
                    Rectangle { anchors.fill: parent; radius: 13; color: ma.containsMouse ? "#f0303030" : "#c0202020"; border.width: 1; border.color: "#40ffffff" }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: modelData.icon
                        color: "white"
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.act === 0 ? lyrics.refreshLyrics() : libraryLoader.active = true
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.text: modelData.tip
                    }
                }
            }
        }
        Loader {
            id: libraryLoader
            active: false
            source: "LibraryWindow.qml"
            onLoaded: { item.visible = true; item.closing.connect(() => libraryLoader.active = false) }
        }
        Row {
            id: nudgeRow
            visible: root.cfg.showSyncControls && hover.hovered && lyrics.synced
            // a quarter of the way up from the bottom edge, centred
            anchors { bottom: parent.bottom; bottomMargin: Math.max(8, parent.height * 0.25); horizontalCenter: parent.horizontalCenter }
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
                    color: root.sideColor
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
