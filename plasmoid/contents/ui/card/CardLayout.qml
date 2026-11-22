import QtQuick
import QtQuick.Controls as QQC2
import org.lyricwidget
import "layouts.js" as Layouts
import "colors.js" as CardColors

// The media card around the lyrics: surface, cover, track text, buttons and the seek bar, laid out by `layoutMode`
// (see layouts.js). Layout 0 shows none of it (today's widget). `player` is the LyricsController (or anything that
// has the same properties); `cfg` is the widget's configuration.
Item {
    id: root
    required property var cfg
    required property var player
    required property int mode          // the layout in force (layouts.js, effectiveMode)
    property color accent: "#6a8cff"
    property var coverColors: []
    property color textColor: "white"
    property color dimColor: "#b0ffffff"
    property string fontFamily: ""
    property real beat: 0
    property bool calm: false
    property color systemAccent: "#3daee9"      // the Plasma accent, for the color sources
    property bool previewMode: false            // the settings preview: no network lookups, no wheel changes

    readonly property var geo: Layouts.layout(mode, width, height, cfg.artSize, 14, {
        posterLines: cfg.posterLines, posterClock: cfg.posterClock, orbitCenter: cfg.orbitCenter,
        edits: cfg.layoutEdits,      // the user's changes to this layout: hidden, moved, resized, see-through parts
        viz: { widthPct: cfg.vizWidthPct, heightPct: cfg.vizHeightPct, hAlign: cfg.vizHAlign, vAlign: cfg.vizVAlign, offX: cfg.vizOffsetX, offY: cfg.vizOffsetY } })
    // where the cover comes from: the player's picture, or a YouTube video's own
    readonly property string artSource: player.thumbUrl !== "" && (cfg.artThumbnail === 1 || player.artUrl === "") ? player.thumbUrl : player.artUrl
    readonly property color controlsColor: CardColors.pick(cfg.controlsColorSource, accent, textColor, systemAccent, cfg.customControlColor)
    readonly property color titleColor: CardColors.pick(cfg.titleColorSource, accent, textColor, systemAccent, cfg.customTitleColor)
    readonly property color progressColor: CardColors.pick(cfg.progressColorSource, accent, textColor, systemAccent, cfg.customProgressColor)
    readonly property bool customOk: cfg.allowCustomQml
    readonly property bool orbitShowsCover: !geo.orbit || cfg.orbitCenter <= 1
    readonly property bool orbitTitleInside: geo.orbit && (cfg.orbitCenter === 1 || cfg.orbitCenter === 2)
    // one alignment setting: left, center or right, or "by the layout" (centered for stacked, orbit and poster)
    readonly property int infoAlign: cfg.textAlign === 1 ? Text.AlignLeft : cfg.textAlign === 2 ? Text.AlignHCenter : cfg.textAlign === 3 ? Text.AlignRight
                                     : mode === 6 || mode === 7 || mode === 8 ? Text.AlignHCenter : Text.AlignLeft
    // what the widget around the card needs to know
    readonly property var lyricsRect: geo.lyrics
    readonly property var toolsRect: geo.tools          // the hover buttons (other lyrics, library) and the sync row: placed by the layout
    readonly property bool toolsRow: geo.toolsRow
    readonly property var nudgeRect: geo.nudge
    readonly property var vizRect: geo.vizRect ?? null
    readonly property var vizPlace: geo.vizPlace         // where the visualizer is drawn (the layout's, or the Visualizer page's), null when hidden
    readonly property var surfaceRect: geo.surface       // the card's background: a part of the card, null when hidden
    readonly property bool vizFill: geo.vizFill
    readonly property bool vizForced: geo.vizForced
    readonly property bool orbit: geo.orbit
    readonly property bool hasCard: mode !== 0 && mode !== 1
    readonly property bool wantsHeaderHidden: mode !== 0

    property real position: 0
    property bool hovered: false
    property bool detailsOpen: false

    Timer {
        interval: 200; repeat: true; triggeredOnStart: true
        running: root.visible && (root.hasCard || root.geo.ring) && root.player.hasPlayer
        onTriggered: root.position = root.player.positionSec()
    }
    Timer { id: hoverFlip; interval: 450; onTriggered: if (root.cfg.trackDetails === 3) root.detailsOpen = true }

    TrackDetails { id: online }
    Connections {
        target: root.player
        function onTrackInfoChanged() { if (!root.previewMode && root.cfg.onlineInfo && root.hasCard) online.lookup(root.player.title, root.player.artist, root.player.album, root.player.lengthSec) }
    }
    Connections {
        target: root.previewMode ? null : root.cfg
        function onOnlineInfoChanged() { if (root.cfg.onlineInfo) online.lookup(root.player.title, root.player.artist, root.player.album, root.player.lengthSec); else online.clear() }
    }

    // pointer: hover shows the buttons; the wheel changes the volume (when on). Handlers (not a MouseArea) so that the
    // buttons and the seek bar on top do not take the hover away and hide themselves.
    HoverHandler {
        id: cardHover
        onHoveredChanged: {
            root.hovered = hovered
            if (!hovered) { hoverFlip.stop(); if (root.cfg.trackDetails === 3) root.detailsOpen = false }
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: !root.previewMode && root.cfg.scrollVolume && root.player.hasPlayer
        onWheel: (e) => root.player.volume = Math.max(0, Math.min(1, root.player.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)))
    }

    // stacking, bottom to top: surface effects (0) < cover and sparks (1) < text (2) < seek bar (5) < buttons (6) < panels (10)

    // ---- a glow ring and sparks round the cover (orbit layout / the sparks setting)
    Rectangle {
        visible: root.geo.orbit && root.cfg.orbitGlowRing && root.geo.vizRect !== undefined && root.geo.vizRect !== null
        x: root.geo.vizRect ? root.geo.vizRect.x + root.geo.vizRect.w * 0.07 : 0
        y: root.geo.vizRect ? root.geo.vizRect.y + root.geo.vizRect.h * 0.07 : 0
        width: root.geo.vizRect ? root.geo.vizRect.w * 0.86 : 0
        height: width; radius: width / 2
        color: "transparent"; border.width: 2; border.color: Qt.alpha(root.accent, 0.55 + 0.4 * root.beat)
    }
    CoverSparks {
        visible: root.cfg.artSparks && root.geo.art !== null && !root.geo.hidden.art
        x: root.geo.art ? root.geo.art.x - 40 : 0
        y: root.geo.art ? root.geo.art.y - 40 : 0
        width: root.geo.art ? root.geo.art.w + 80 : 0
        height: root.geo.art ? root.geo.art.h + 80 : 0
        inset: 40
        beat: root.beat; accent: root.accent; calm: root.calm
        active: root.cfg.artSparks
    }

    // ---- the cover, with its details on the back when "flip" is the details view
    Flipable {
        id: flip
        z: 1
        opacity: root.geo.opacity.art ?? 1
        // the cover can be hidden while the progress ring round it stays (Edit the layout)
        visible: root.geo.art !== null && root.orbitShowsCover && (!root.geo.hidden.art || (root.geo.ring && !root.geo.hidden.ring))
        x: root.geo.art ? root.geo.art.x : 0
        y: root.geo.art ? root.geo.art.y : 0
        width: root.geo.art ? (root.cfg.artFormat === 1 && root.cfg.artShape < 3 ? Math.min(root.geo.art.w * 4 / 3, root.width / 2) : root.geo.art.w) : 0
        height: root.geo.art ? root.geo.art.h : 0
        property bool flipped: root.cfg.trackDetails === 3 && root.detailsOpen
        transform: Rotation { origin.x: flip.width / 2; origin.y: flip.height / 2; axis { x: 0; y: 1; z: 0 } angle: flip.flipped ? 180 : 0
            Behavior on angle { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } } }
        front: Artwork {
            anchors.fill: parent
            source: root.artSource
            shape: root.cfg.artShape
            borderWidth: root.cfg.artBorder
            borderColor: root.dimColor
            glow: root.cfg.artGlow
            tilt: root.cfg.artTilt
            reflect: root.cfg.artReflect
            grey: root.cfg.artGreyPaused && !root.player.playing
            spin: root.cfg.artSpin
            playing: root.player.playing
            wide: root.cfg.artFormat === 1
            fallback: root.cfg.artFallback
            fit: root.cfg.artFit
            focusH: root.cfg.artFocusH
            focusV: root.cfg.artFocusV
            letter: root.player.title
            showCover: !root.geo.hidden.art
            progress: (root.geo.ring || root.cfg.progressStyle === 11) && !root.geo.hidden.ring && root.player.lengthSec > 0 ? root.position / root.player.lengthSec : -1
            accent: root.accent
            beat: root.geo.orbit && !root.cfg.orbitCoverPulse ? 0 : root.beat
            calm: root.calm
            onClicked: {
                if (root.cfg.artClick === 1) root.player.playPause()
                else if (root.cfg.artClick === 2) root.detailsOpen = !root.detailsOpen
            }
        }
        back: DetailsPanel {
            anchors.fill: parent
            title: root.player.title; artist: root.player.artist; album: root.player.album
            lengthSec: root.player.lengthSec; positionSec: root.position
            volume: root.player.volume; shuffle: root.player.shuffle; loop: root.player.loopStatus
            online: root.cfg.onlineInfo; busy: online.busy; year: root.cfg.detailYear ? online.year : ""; country: root.cfg.detailCountry ? online.country : ""; label: root.cfg.detailLabel ? online.label : ""; tags: root.cfg.detailTags ? online.tags : ""; about: root.cfg.detailAbout ? online.about : ""
            textColor: root.textColor; accent: root.accent
            clip: true
        }
    }
    HoverHandler { id: artHover; target: flip; onHoveredChanged: if (hovered && root.cfg.trackDetails === 3) hoverFlip.restart(); else hoverFlip.stop() }

    // ---- title, artist (album)
    TrackInfo {
        id: info
        z: 2
        x: root.geo.info ? root.geo.info.x : 0
        y: root.geo.info ? root.geo.info.y : 0
        width: root.geo.info ? root.geo.info.w : 0
        height: root.geo.info ? root.geo.info.h : 0
        title: root.player.title; artist: root.player.artist; album: root.player.album
        showAlbum: root.cfg.trackShowAlbum
        textStyle: root.cfg.trackTextStyle
        scroll: root.cfg.trackScroll
        calm: root.calm
        headline: root.geo.headline
        titleSize: root.geo.infoSize > 0 ? root.geo.infoSize : root.cfg.titleSize
        opacity: root.geo.opacity.info ?? 1
        maxHeadlineLines: root.mode === 8 ? root.cfg.posterLines : 2
        align: root.infoAlign
        visible: root.geo.info !== null && !root.orbitTitleInside
        textColor: root.textColor; titleColor: root.titleColor; dimColor: root.dimColor
        fontFamily: root.fontFamily
        onHoveredChanged: if (hovered && root.cfg.trackDetails === 3) hoverFlip.restart()
        onClicked: if (root.cfg.trackDetails === 2) root.detailsOpen = !root.detailsOpen
        QQC2.ToolTip.visible: hovered && root.cfg.trackDetails === 1
        QQC2.ToolTip.delay: 300
        QQC2.ToolTip.text: root.player.title + "\n" + root.player.artist + (root.player.album ? "\n" + root.player.album : "")
                           + (root.cfg.onlineInfo && (online.year || online.label) ? "\n" + [online.year, online.label].filter(x => x).join(" · ") : "")
    }

    // orbit with the title in the middle of the ring (and the cover too when it is "cover and title")
    TrackInfo {
        visible: root.orbitTitleInside && root.geo.vizRect !== undefined && root.geo.vizRect !== null
        x: root.geo.vizRect ? root.geo.vizRect.x + root.geo.vizRect.w * 0.2 : 0
        y: root.geo.vizRect ? root.geo.vizRect.y + root.geo.vizRect.h * (root.cfg.orbitCenter === 1 ? 0.62 : 0.38) : 0
        width: root.geo.vizRect ? root.geo.vizRect.w * 0.6 : 0
        height: root.geo.vizRect ? root.geo.vizRect.h * 0.28 : 0
        title: root.player.title; artist: root.player.artist
        align: Text.AlignHCenter; titleSize: Math.max(12, root.cfg.titleSize - 2); scroll: root.cfg.trackScroll; calm: root.calm
        textColor: root.textColor; titleColor: root.titleColor; dimColor: root.dimColor; fontFamily: root.fontFamily
    }
    // which player this is, and a button to switch when there are two
    Row {
        visible: root.geo.info !== null && (root.cfg.showSource || (root.cfg.showPlayerSwitch && root.player.playerCount > 1))
        x: root.geo.info ? root.geo.info.x + root.geo.info.w - width : 0
        y: root.geo.info ? root.geo.info.y - 2 : 0
        spacing: 6
        Text { visible: root.cfg.showSource; text: root.player.playerName; color: root.dimColor; font.pixelSize: 10; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            visible: root.cfg.showPlayerSwitch && root.player.playerCount > 1
            width: 20; height: 20; radius: 10; color: "#44000000"; border.width: 1; border.color: "#33ffffff"
            Text { anchors.centerIn: parent; text: "⇄"; color: root.textColor; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player.cyclePlayer()
                        hoverEnabled: true; QQC2.ToolTip.visible: containsMouse; QQC2.ToolTip.text: qsTr("Switch player") }
        }
    }

    // the drawer: a wider details panel under the text
    DetailsPanel {
        visible: root.cfg.trackDetails === 2 && root.detailsOpen && root.geo.info !== null
        x: root.geo.info ? Math.max(4, Math.min(root.width - width - 4, root.geo.info.x)) : 0
        y: root.geo.info ? root.geo.info.y + root.geo.info.h + 4 : 0
        width: Math.min(root.width - 8, 340)
        title: root.player.title; artist: root.player.artist; album: root.player.album
        lengthSec: root.player.lengthSec; positionSec: root.position
        volume: root.player.volume; shuffle: root.player.shuffle; loop: root.player.loopStatus
        online: root.cfg.onlineInfo; busy: online.busy; year: root.cfg.detailYear ? online.year : ""; country: root.cfg.detailCountry ? online.country : ""; label: root.cfg.detailLabel ? online.label : ""; tags: root.cfg.detailTags ? online.tags : ""; about: root.cfg.detailAbout ? online.about : ""
        textColor: root.textColor; accent: root.accent
        z: 10
    }

    // ---- buttons (or the user's own file)
    Item {
        id: dock
        z: 6
        visible: root.geo.controls !== null && root.cfg.controlsShow !== 0
        opacity: (root.cfg.controlsShow === 2 || root.hovered ? 1 : 0) * (root.geo.opacity.controls ?? 1)
        Behavior on opacity { NumberAnimation { duration: 180 } }
        x: root.geo.controls ? root.geo.controls.x : 0
        y: root.geo.controls ? root.geo.controls.y : 0
        width: root.geo.controls ? root.geo.controls.w : 0
        height: root.geo.controls ? root.geo.controls.h : 0
        readonly property bool custom: root.cfg.dockStyle === 6 && root.customOk && root.cfg.customButtonsFile !== ""
        Controls {
            anchors.fill: parent
            visible: !dock.custom
            dockStyle: Math.min(root.cfg.dockStyle, 5)
            align: root.geo.controlsAlign
            playing: root.player.playing
            showSkip: root.cfg.showSkip
            showShuffleRepeat: root.cfg.showShuffleRepeat
            shuffle: root.player.shuffle
            loop: root.player.loopStatus
            accent: root.accent
            iconColor: root.controlsColor
            onPrevious: root.player.previousTrack()
            onToggle: root.player.playPause()
            onNext: root.player.nextTrack()
            onToggleShuffle: root.player.shuffle = !root.player.shuffle
            onCycleLoop: root.player.loopStatus = root.player.loopStatus === "None" ? "Playlist" : root.player.loopStatus === "Playlist" ? "Track" : "None"
        }
        CustomButtons {
            anchors.fill: parent
            visible: dock.custom
            file: dock.custom ? root.cfg.customButtonsFile : ""
            playing: root.player.playing; shuffle: root.player.shuffle; loop: root.player.loopStatus
            accent: root.accent; iconColor: root.controlsColor
            showSkip: root.cfg.showSkip; showShuffleRepeat: root.cfg.showShuffleRepeat
            onPrevious: root.player.previousTrack()
            onToggle: root.player.playPause()
            onNext: root.player.nextTrack()
            onToggleShuffle: root.player.shuffle = !root.player.shuffle
            onCycleLoop: root.player.loopStatus = root.player.loopStatus === "None" ? "Playlist" : root.player.loopStatus === "Playlist" ? "Track" : "None"
        }
    }

    // ---- seek bar (or the user's own file)
    Item {
        id: seek
        z: 5
        opacity: root.geo.opacity.progress ?? 1
        visible: root.geo.progress !== null && root.cfg.progressStyle !== 0 && root.cfg.progressStyle !== 11
        x: root.geo.progress ? root.geo.progress.x : 0
        y: root.geo.progress ? root.geo.progress.y : 0
        width: root.geo.progress ? root.geo.progress.w : 0
        height: root.geo.progress ? root.geo.progress.h : 0
        readonly property bool custom: root.cfg.progressStyle === 12 && root.customOk && root.cfg.customProgressFile !== ""
        ProgressBar {
            anchors.fill: parent
            visible: !seek.custom
            style: Math.min(root.cfg.progressStyle, 10)
            position: root.position
            length: root.player.lengthSec
            playing: root.player.playing
            accent: root.progressColor
            track: Qt.alpha(root.textColor, 0.22)
            textColor: root.textColor
            beat: root.beat
            labels: root.cfg.timeLabels
            wheelStep: root.cfg.wheelSeekSec
            doubleClickJump: root.cfg.doubleClickSkip
            seed: root.player.title + root.player.artist
            calm: root.calm
            chapters: root.player.chapters
            showChapters: root.cfg.showChapters
            seekHover: root.cfg.seekHover
            reactive: root.cfg.reactiveProgress
            onSeekTo: (s) => { root.player.seekToSec(s); root.position = s }
            onSeekBy: (d) => { root.player.seekBySec(d); root.position = Math.max(0, root.position + d) }
        }
        CustomProgress {
            anchors.fill: parent
            visible: seek.custom
            file: seek.custom ? root.cfg.customProgressFile : ""
            position: root.position; length: root.player.lengthSec; playing: root.player.playing
            accent: root.progressColor; textColor: root.textColor; beat: root.beat
            chapters: root.player.chapters; labels: root.cfg.timeLabels
            onSeekTo: (s) => { root.player.seekToSec(s); root.position = s }
            onSeekBy: (d) => { root.player.seekBySec(d); root.position = Math.max(0, root.position + d) }
        }
    }

    // ---- the clock of the poster layout
    Text {
        id: clock
        z: 2
        visible: root.geo.clock !== null
        x: root.geo.clock ? root.geo.clock.x : 0
        y: root.geo.clock ? root.geo.clock.y : 0
        width: root.geo.clock ? root.geo.clock.w : 0
        height: root.geo.clock ? root.geo.clock.h : 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.textColor; opacity: 0.85 * (root.geo.opacity.clock ?? 1)
        font.pixelSize: Math.max(18, height * 0.9)
        font.family: root.fontFamily
        text: Qt.formatTime(new Date(), "HH:mm")
        Timer { interval: 20000; repeat: true; running: clock.visible; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
    }
}
