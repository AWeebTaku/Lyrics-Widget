import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.lyricwidget
import "audioviz"
import "card"
import "card/layouts.js" as Layouts
import "card/colors.js" as CardColors
import "viz/presets.js" as Presets

PlasmoidItem {
    id: root

    // Plasma shows one settings dialog at a time (opening a second widget's settings closes the first). So the menu's "Configure…"
    // opens this widget's settings in a window of its own instead (Plasma's own entry is taken out, so there is one), and the
    // settings of several widgets can be open together.
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Configure %1…", Plasmoid.title)
            icon.name: "configure"
            onTriggered: root.openSettingsWindow()
        },
        PlasmaCore.Action {
            text: i18n("Random look")
            icon.name: "roll"
            onTriggered: root.applyLook(Presets.randomPick(Presets.all(root.cfg.vizUserPresets, root.cfg.vizFavourites), ""))
        },
        PlasmaCore.Action {
            text: i18n("Go back to before the last look")
            icon.name: "edit-undo"
            visible: Presets.parseUser(root.cfg.vizUserPresets).some(p => p.name === root.undoName)
            onTriggered: root.applyLook(Presets.parseUser(root.cfg.vizUserPresets).find(p => p.name === root.undoName))
        }
    ]
    // A look from the widget's menu does what picking it in Settings does: the setup it replaces is saved as "Before the last look"
    readonly property string undoName: i18n("Before the last look")
    function applyLook(p) {
        if (!p) return
        const w = settingsWindow.item           // an open settings window learns the new values too, so it does not write the old ones back
        const set = (k, v) => { if (w) w.setKey(k, v); else cfg[k] = v }
        const before = {}
        for (const k in Presets.keys) before[k] = w ? w.get(k) : cfg[k]
        set("vizUserPresets", Presets.saveUser(cfg.vizUserPresets, undoName, before))
        for (const k in p.settings) set(k, p.settings[k])
        cfg.writeConfig()
    }
    function openSettingsWindow() {
        if (settingsWindow.item) { settingsWindow.item.raise(); settingsWindow.item.requestActivate() }
        else settingsWindow.active = true
    }
    Loader {
        id: settingsWindow
        active: false
        source: "SettingsWindow.qml"
        onLoaded: {
            item.cfg = Plasmoid.configuration
            item.live = lyrics
            item.widgetName = root.cardMode === 0 ? i18n("lyrics") : Layouts.modes[root.cardMode].name
            item.load()
            item.visible = true
            item.closing.connect(() => settingsWindow.active = false)
            item.libraryRequested.connect(() => settingsLibrary.active = true)
        }
    }
    Loader {
        id: settingsLibrary      // the lyrics library, from the settings window (the widget's hover button opens the same window)
        active: false
        source: "LibraryWindow.qml"
        onLoaded: { item.live = lyrics; item.visible = true; item.closing.connect(() => settingsLibrary.active = false) }
    }

    // On the desktop the widget is the card. In a panel it is the card, a small pill that opens the card, or (adaptive)
    // the card when the panel is thick enough for it and the pill when it is not.
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool panelVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int cardMode: Layouts.effectiveMode(cfg)
    readonly property var cardNatural: Layouts.naturalSize(cardMode)
    // a vertical panel too narrow for an upright card turns it on its side (automatic), or as asked
    readonly property int panelRotation: !inPanel ? 0 : cfg.panelOrientation === 1 ? 0 : cfg.panelOrientation === 2 ? -90 : cfg.panelOrientation === 3 ? 90
                                         : (panelVertical && width < cardNatural[0] * 0.8 ? 90 : 0)
    readonly property var cardFit: panelRotation === 0 ? cardNatural : [cardNatural[1], cardNatural[0]]
    readonly property real panelThickness: panelVertical ? width : height
    // the panel's thickness is the panel's own decision, so asking for the card cannot change the answer
    readonly property bool roomForCard: panelThickness >= cardFit[panelVertical ? 0 : 1] * 0.8
    readonly property bool cardInPanel: cfg.panelMode === 0 || (cfg.panelMode === 2 && roomForCard)
    readonly property real cardFactor: cfg.panelCardSizing === 1 ? Math.max(0.5, cfg.panelCardScale / 100)
                                       : Math.min(4, Math.max(1, panelThickness / cardFit[panelVertical ? 0 : 1]))
    preferredRepresentation: inPanel && !cardInPanel ? compactRepresentation : fullRepresentation
    compactRepresentation: Pill {
        player: lyrics
        cfg: root.cfg
        accent: root.cardAccent
        textColor: root.fg
        onClicked: { if (cfg.pillClick === 1) lyrics.playPause(); else if (cfg.pillClick === 2) lyrics.nextTrack(); else if (cfg.pillPopupTrigger !== 1) root.expanded = !root.expanded }
        onMiddleClicked: lyrics.playPause()
        onHoveredChanged: root.pillHover(hovered)
    }
    // hovering the pill can open the card as clicking does; it closes again a moment after the pointer has left both
    property bool pinned: false
    hideOnWindowDeactivate: !pinned
    function pillHover(on) {
        if (cfg.pillPopupTrigger === 0 || cfg.pillClick !== 0) return
        if (on) { closeCard.stop(); if (!expanded) openCard.restart() } else { openCard.stop(); closeCard.restart() }
    }
    Timer { id: openCard; interval: 350; onTriggered: root.expanded = true }
    Timer { id: closeCard; interval: 450; onTriggered: if (!root.pinned && !hover.hovered) root.expanded = false }
    // "Blur behind the card": let Plasma draw its own (blurred) background behind a glass card
    Plasmoid.backgroundHints: cfg.compositorGlass && (cfg.cardSurface === 3 || cfg.cardSurface === 4) ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground
    // Size: 0 = free, 1 = fixed width/height from settings, 2 = full screen width (+ height)
    // (a fixed size of 0 means "as small as possible": 1 px; a free widget can be dragged down to 1 px)
    readonly property real wantW: cfg.sizeMode === 2 ? Screen.width : (cfg.sizeMode === 1 ? Math.max(1, cfg.widthPx) : 0)
    readonly property real wantH: cfg.sizeMode === 0 ? 0 : Math.max(1, cfg.heightPx)
    Layout.minimumWidth: wantW > 0 ? wantW : 1
    Layout.preferredWidth: wantW > 0 ? wantW : (inPanel && cardInPanel && cardMode > 1 ? cardFit[0] * cardFactor : 760)
    Layout.maximumWidth: wantW > 0 ? wantW : Number.POSITIVE_INFINITY
    Layout.minimumHeight: wantH > 0 ? wantH : 1
    Layout.preferredHeight: wantH > 0 ? wantH : (inPanel && cardInPanel && cardMode > 1 ? cardFit[1] * cardFactor : 220)
    Layout.maximumHeight: wantH > 0 ? wantH : Number.POSITIVE_INFINITY

    readonly property var cfg: Plasmoid.configuration

    // The old "Background" setting (a plain colored panel) is now the Color surface of the card: carry it over once.
    Component.onCompleted: {
        Plasmoid.removeInternalAction("configure")      // replaced by the entry above
        if (cfg.showPanel) {
            if (cfg.cardSurface === 0)
                cfg.cardSurface = 1
            cfg.showPanel = false
            cfg.writeConfig()
        }
    }

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
    // Colors of the album cover (when switched on): the main one for the current line, the second for the
    // other lines, all of them as a gradient in the visualizer
    readonly property bool tinted: cfg.tintFromArt && lyrics.palette.length > 0
    // A very dark cover color would make the text vanish on a dark desktop: lift it to half brightness
    function lift(c) {
        return c.hslLightness < 0.5 ? Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, 0.5, c.a) : c
    }
    // "Switch the lyric text to dark on a light background": when the color behind the text (the card color or the
    // panel) is a light, mostly opaque one, the text colors become dark
    readonly property var backdrop: Layouts.luminance(cfg.cardSurface === 1 || cfg.cardSurface === 6 ? cfg.panelColor : "")
    readonly property bool lightBackdrop: cfg.autoContrast && backdrop !== null && backdrop.alpha > 0.45 && backdrop.lum > 0.4
    readonly property color fg: lightBackdrop ? "#15171c" : cfg.textColor
    readonly property color fgDim: lightBackdrop ? "#8015171c" : cfg.dimColor
    readonly property color curColor: tinted ? lift(lyrics.palette[0]) : fg
    // the card's accent: the cover's main color, else the lyric color
    readonly property color cardAccent: CardColors.accent(cfg.cardAccentSource, curColor,
                                                          Kirigami.Theme.highlightColor, cfg.customAccent)
    // "One color" uses only the cover's main color (current line and visualizer); the other lines keep their own
    readonly property bool multiColor: tinted && cfg.tintMode === 0 && lyrics.palette.length > 1
    readonly property color sideColor: multiColor ? Qt.alpha(lift(lyrics.palette[1]), 0.8) : fgDim

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
        karaoke: root.cfg.karaoke
        preferThumbnail: root.cfg.artThumbnail === 1      // the colors come from the picture that is shown
        localLyrics: root.cfg.localLyrics
        localLyricsFolder: root.cfg.localLyricsFolder
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
      id: frame
      implicitWidth: root.cardFit[0] * root.cardFactor
      implicitHeight: root.cardFit[1] * root.cardFactor
      Item {
        id: view
        // a card on its side (vertical panel) is laid out upright, then turned
        width: root.panelRotation !== 0 ? frame.height : frame.width
        height: root.panelRotation !== 0 ? frame.width : frame.height
        anchors.centerIn: parent
        rotation: root.panelRotation
        clip: true
        scale: root.cfg.hoverLift && hover.hovered ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 160 } }
        opacity: ((root.cfg.hideWhenNothingPlaying && lyrics.idle) || root.faded || root.covered) ? 0
                 : (root.cfg.dimWhenPaused && !lyrics.playing && !lyrics.idle ? 0.55 : 1)
        Behavior on opacity { NumberAnimation { duration: 250 } }


        // what the music is doing, from the visualizer (which is only there while it is on and music plays)
        readonly property real vizBass: vizLoader.item ? vizLoader.item.bass : 0
        readonly property real vizMid: vizLoader.item ? vizLoader.item.mid : 0
        readonly property real vizBeat: vizLoader.item ? vizLoader.item.beat : 0
        readonly property bool calm: root.cfg.reducedMotion || root.cfg.batterySaver

        // soft glow along the edges: one that flashes with the bass, one that stays and breathes with the mids
        component GlowFrame: Item {
            id: gf
            property real amount: 0   // 0..1
            property real width_: 10
            // the glow runs along the edge of the card's background (a part of the card, see layouts.js)
            x: card.surfaceRect ? card.surfaceRect.x : 0
            y: card.surfaceRect ? card.surfaceRect.y : 0
            width: card.surfaceRect ? card.surfaceRect.w : 0
            height: card.surfaceRect ? card.surfaceRect.h : 0
            visible: amount > 0.01 && card.surfaceRect !== null
            Rectangle {
                id: gfSrc
                anchors.fill: parent
                color: "transparent"
                radius: root.cfg.cardSurface !== 0 ? root.cfg.panelRadius : 0
                border.width: gf.width_
                border.color: root.curColor
                layer.enabled: gf.visible
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: gfSrc
                blurEnabled: true
                blurMax: 48
                blur: 1.0
                opacity: Math.min(1, gf.amount)
            }
        }
        GlowFrame {
            amount: view.calm ? 0 : root.cfg.panelGlow / 100 * (0.1 + 0.9 * view.vizBass)
        }
        GlowFrame {
            width_: 16
            amount: root.cfg.ambientGlow / 100 * (view.calm ? 0.5 : 0.35 + 0.4 * view.vizMid)
        }

        // the card's background (the layouts, Settings > Card); under the visualizer
        CardSurface {
            x: card.surfaceRect ? card.surfaceRect.x : 0
            y: card.surfaceRect ? card.surfaceRect.y : 0
            width: card.surfaceRect ? card.surfaceRect.w : 0
            height: card.surfaceRect ? card.surfaceRect.h : 0
            visible: card.surfaceRect !== null
            opacity: card.geo.opacity.surface ?? 1
            type: root.cfg.cardSurface
            source: lyrics.artUrl
            coverColors: lyrics.palette
            accent: root.cardAccent
            tint: root.cfg.panelColor
            blur: root.cfg.surfaceBlur
            dim: root.cfg.surfaceDim
            radius: root.cfg.panelRadius
            grain: root.cfg.surfaceGrain
            shadow: root.cfg.surfaceShadow
            edge: root.cfg.surfaceEdge
            calm: view.calm
        }

        // the audio visualizer (the canvas renderer + cava), behind the lyrics;
        // the Loader keeps cava off unless it is wanted and music is playing. Show: Visualizer (General) decides: the layouts built
        // around the music (hero wave, orbit, poster) need it on, and the looks that use them turn it on.
        Loader {
            id: vizLoader
            active: root.cfg.showVisualizer && card.vizPlace !== null && !lyrics.idle && (lyrics.playing || root.cfg.hideAfterSec > 0) && !root.suspended && !root.covered
            source: "AudioViz.qml"
            onLoaded: {
                item.tintFlow = Qt.binding(() => root.cfg.vizColorFlow)
                item.tintColors = Qt.binding(() => {
                    const cover = root.cfg.vizColorMode === 4 && lyrics.palette.length > 0      // the visualizer's own "colors from the album cover"
                    if (!root.tinted && !cover) return []
                    return root.multiColor || cover ? lyrics.palette.map(c => c.toString()) : [lyrics.palette[0].toString()]
                })
                item.styleOverride = Qt.binding(() => card.orbit ? 16 : -1)   // 16 = the orbit ring
            }
            // size as a share of the widget, placed on a 3x3 grid plus a pixel offset; a layout may take over the place
            width: card.vizPlace ? card.vizPlace.w : 0
            height: card.vizPlace ? card.vizPlace.h : 0
            x: card.vizPlace ? card.vizPlace.x : 0
            y: card.vizPlace ? card.vizPlace.y : 0
            // the poster lays the music behind the title at a set strength; the music can also fade while paused
            opacity: (root.cardMode === 8 && root.cfg.posterVizBehind ? root.cfg.posterVizOpacity / 100 : 1)
                     * (root.cfg.fadeVizWhenPaused && !lyrics.playing ? 0.25 : 1) * (card.geo.opacity.viz ?? 1)
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // the media card: cover, title, buttons, seek bar (layout 0, "Lyrics only", shows none of it)
        CardLayout {
            id: card
            anchors.fill: parent
            cfg: root.cfg
            mode: root.cardMode
            player: lyrics
            accent: root.cardAccent
            systemAccent: Kirigami.Theme.highlightColor
            coverColors: lyrics.palette
            textColor: root.fg
            dimColor: root.fgDim
            fontFamily: root.cfg.fontFamily
            beat: view.vizBeat
            calm: view.calm
        }

        // where the lyrics go: all of the widget, or what the layout leaves for them
        readonly property bool lyricsShown: card.lyricsRect !== null
        readonly property bool cardOn: root.cardMode > 1                 // with a card the layout places the lyrics: only their alignment applies
        readonly property real offX: cardOn ? 0 : root.cfg.lyricsOffsetX
        readonly property real offY: cardOn ? 0 : root.cfg.lyricsOffsetY
        readonly property real lx: card.lyricsRect ? card.lyricsRect.x : 0
        readonly property real ly: card.lyricsRect ? card.lyricsRect.y : 0
        readonly property real lw: card.lyricsRect ? card.lyricsRect.w : view.width
        readonly property real lh: card.lyricsRect ? card.lyricsRect.h : view.height

        // artist — title
        Text {
            visible: root.cfg.showHeader && lyrics.title !== "" && !card.wantsHeaderHidden
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
            x: view.lx + 20 + view.offX
            y: view.ly + view.offY
            width: view.lw - 40
            height: view.lh
            visible: view.lyricsShown && root.cfg.showLyrics && lyrics.lines.length === 0 && root.cfg.sideSize > 0
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
            x: view.lx + 20 + view.offX
            y: view.ly + view.offY
            opacity: card.geo.opacity.lyrics ?? 1
            // the lyrics swell a little with each beat (off by default; needs the visualizer)
            scale: 1 + (view.calm ? 0 : root.cfg.lyricPulse / 100 * 0.07 * view.vizBeat)
            width: view.lw - 40
            height: view.lh
            hAlign: root.cfg.lyricsHAlign
            vAlign: root.cfg.lyricsVAlign
            visible: view.lyricsShown && root.cfg.showLyrics && lyrics.synced
            cfg: root.cfg
            index: lyrics.currentIndex
            gapMs: lyrics.lineGapMs
            animate: root.cfg.animateLines && !view.calm
            curColor: root.curColor
            curColors: root.multiColor ? lyrics.palette.slice(0, 4).map(c => root.lift(c)) : []
            curFlow: root.cfg.lyricColorFlow
            sideColor: root.sideColor
            hidden: lyrics.lineHidden
            showSides: root.cfg.showNeighbours && view.lh >= 150   // no room for them in a small widget
            id: stage
            // the karaoke effect: polled while playing (the position has no signal)
            function readLine() {
                stage.durMs = lyrics.lineDurMs()
                stage.wordStarts = lyrics.lineWords()
                stage.elapsed = lyrics.lineElapsedMs()
            }
            Timer {
                interval: 33
                repeat: true
                running: root.cfg.karaoke && lyrics.playing && stage.visible && !root.suspended && !root.covered
                triggeredOnStart: true
                onTriggered: stage.elapsed = lyrics.lineElapsedMs()
                onRunningChanged: { if (running) stage.readLine(); else if (!root.cfg.karaoke) stage.elapsed = -1 }
            }
            Connections {
                target: lyrics
                function onCurrentIndexChanged() { if (root.cfg.karaoke) stage.readLine() }
            }
            prev: root.lineAt(lyrics.currentIndex - 1).replace(/\n/g, "  ·  ")
            cur: root.lineAt(lyrics.currentIndex)
            next: root.lineAt(lyrics.currentIndex + 1).replace(/\n/g, "  ·  ")
        }

        // unsynced fallback: static block
        Text {
            x: view.lx + 30 + view.offX
            y: view.ly + 30 + view.offY
            width: view.lw - 60
            height: view.lh - 60
            visible: view.lyricsShown && root.cfg.showLyrics && lyrics.lines.length > 0 && !lyrics.synced && root.cfg.sideSize > 0
            horizontalAlignment: view.hAlign
            verticalAlignment: view.vAlign
            elide: Text.ElideRight
            clip: true
            text: lyrics.lines.map((l, i) => (root.cfg.showRoman && lyrics.roman[i]) || l).join("\n")
            color: root.fg
            font.family: root.cfg.fontFamily
            font.pixelSize: Math.max(1, root.cfg.sideSize)
        }

        // Hover to nudge this song's timing (remembered per song): + = lyrics earlier, - = later.
        // Off by default; Settings -> Lyrics -> Lines and timing.
        HoverHandler { id: hover }
        // what a button just did or could not do (looking for other lyrics, say), for a few seconds
        Rectangle {
            visible: lyrics.notice !== ""
            z: 30
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
            width: Math.min(parent.width - 24, noticeText.implicitWidth + 24)
            height: noticeText.implicitHeight + 12
            radius: height / 2
            color: "#e0202020"
            border.width: 1; border.color: "#40ffffff"
            Text { id: noticeText; anchors.centerIn: parent; width: parent.width - 24; text: lyrics.notice; color: "white"; font.pixelSize: 12; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
        }
        // Hover buttons, top right: look for other lyrics (saved to the library) and open the library
        Grid {
            visible: root.cfg.hoverButtons && hover.hovered && !lyrics.idle && card.toolsRect !== null
            columns: card.toolsRow ? 2 : 1
            z: 20      // above the card, so hovering them keeps them
            // where the layout says (beside the lyrics), or where the user moved it: Settings, Card, Edit the layout
            x: card.toolsRect ? card.toolsRect.x : 0
            y: card.toolsRect ? card.toolsRect.y : 0
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
            onLoaded: { item.live = lyrics; item.visible = true; item.closing.connect(() => libraryLoader.active = false) }
        }
        // on a card the sync row sits over the lyrics' edge: a soft backing keeps it readable (a sibling: a child of the Row would be laid out in it)
        Rectangle {
            visible: nudgeRow.visible && view.cardOn
            z: 19
            x: nudgeRow.x - 10; y: nudgeRow.y - 3; width: nudgeRow.width + 20; height: nudgeRow.height + 6
            radius: height / 2; color: "#80000000"
        }
        Row {
            id: nudgeRow
            visible: root.cfg.showSyncControls && hover.hovered && lyrics.synced && card.nudgeRect !== null
            z: 20      // above the card, so hovering them keeps them
            // a quarter of the way up from the bottom edge, centered; with a card, at the bottom of the space the layout gives the lyrics
            x: card.nudgeRect ? card.nudgeRect.x + (card.nudgeRect.w - width) / 2 : 0
            y: card.nudgeRect ? card.nudgeRect.y + card.nudgeRect.h - height : 0
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

        // pin: keep the opened card up when you click elsewhere (a card opened from a panel pill)
        Rectangle {
            visible: root.inPanel && root.expanded
            anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
            width: 24; height: 24; radius: 12
            color: root.pinned ? Qt.alpha(root.cardAccent, 0.9) : "#99202020"
            border.width: 1; border.color: "#44ffffff"
            Kirigami.Icon { anchors.centerIn: parent; width: 14; height: 14; source: root.pinned ? "window-unpin" : "window-pin"; color: "white" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pinned = !root.pinned
                        QQC2.ToolTip.visible: containsMouse; QQC2.ToolTip.text: root.pinned ? "Unpin" : "Keep this open"; hoverEnabled: true }
        }
      }
    }
}
