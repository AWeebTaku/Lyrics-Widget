pragma ComponentBehavior: Bound
import QtQuick

// Shows previous / current / next lyric lines. A new line cross-fades in while sliding up, driven by
// ONE progress value `t` (no per-line animation objects). Seeks, pauses and very fast lines snap.
Item {
    id: stage

    required property var cfg          // Plasmoid.configuration
    property string prev
    property string cur
    property string next
    property int index: -1
    property int gapMs: 2000           // how long the current line stays on screen
    property bool animate: true
    property bool showSides: true
    property int hAlign: 1             // 0 left, 1 centre, 2 right
    property int vAlign: 1             // 0 top, 1 middle, 2 bottom
    readonly property int textAlign: hAlign === 0 ? Text.AlignLeft : hAlign === 2 ? Text.AlignRight : Text.AlignHCenter
    property color curColor: cfg.textColor
    property real bpm: 0                // detected tempo, 0 = unknown
    property bool pulseOn: false
    property real kick: 0              // 1 right after a beat, fades to 0
    function beat() { if (pulseOn) { kickAnim.restart() } }
    NumberAnimation { id: kickAnim; target: stage; property: "kick"; from: 1; to: 0; duration: 260; easing.type: Easing.OutQuad }
    property real karaokeFrac: -1      // 0..1 of the current line sung, -1 = no word timing

    property int active: 0             // slot holding the current line
    property int shownIndex: -2
    property real t: 1                 // 0..1 progress of the running transition
    property real lift: cfg.mainSize * 0.8

    onIndexChanged: Qt.callLater(refresh)   // let prev/cur/next bindings settle first
    onCurChanged: Qt.callLater(refresh)
    onPrevChanged: Qt.callLater(refresh)
    onNextChanged: Qt.callLater(refresh)

    function slot(i) { return i === 0 ? a : b }

    function refresh() {
        const step = Math.abs(index - shownIndex)
        shownIndex = index
        anim.stop()
        if (step !== 1 || !animate || gapMs < 180) {   // same line (text change), seek, or too fast
            slot(active).set(prev, cur, next)
            t = 1
            return
        }
        active = 1 - active
        slot(active).set(prev, cur, next)
        // fast songs get a short transition, slow songs a calmer one; never longer than the line itself
        // ...and with the tempo: about half a beat when it is known
        const byBeat = bpm > 0 ? 30000 / bpm : 1e9
        anim.duration = Math.max(90, Math.min(420, gapMs * 0.35, byBeat))
        stage.lift = cfg.mainSize * 0.8 * Math.min(1, anim.duration / 420)
        t = 0
        anim.start()
    }

    NumberAnimation { id: anim; target: stage; property: "t"; from: 0; to: 1; easing.type: Easing.OutCubic }

    component Stack: Column {
        id: col
        required property int slotIndex
        width: stage.width
        y: stage.vAlign === 0 ? 0 : stage.vAlign === 2 ? stage.height - height : (stage.height - height) / 2
        spacing: 10
        readonly property bool isActive: stage.active === slotIndex
        opacity: isActive ? 0.3 + 0.7 * stage.t : Math.max(0, 1 - stage.t * 1.6)
        transform: [
            Translate { y: col.isActive ? (1 - stage.t) * stage.lift : -stage.t * stage.lift * 0.4 },
            Scale { origin.x: col.width / 2; origin.y: col.height / 2
                    xScale: col.isActive ? 1 + 0.035 * stage.kick : 1; yScale: xScale }
        ]

        property alias prevText: p.text
        property alias curText: c.text
        property alias nextText: n.text
        function set(pv, cu, nx) { p.text = pv; c.text = cu; n.text = nx }

        Text {
            id: p
            visible: stage.showSides && stage.cfg.sideSize > 0
            width: parent.width
            horizontalAlignment: stage.textAlign
            elide: Text.ElideRight
            color: stage.cfg.dimColor
            font.family: stage.cfg.fontFamily
            font.pixelSize: Math.max(1, stage.cfg.sideSize)
        }
        Text {
            id: c
            width: parent.width
            visible: stage.cfg.mainSize > 0
            height: stage.cfg.mainSize * 3.2   // room for layered lines, then shrink to fit
            horizontalAlignment: stage.textAlign
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            fontSizeMode: Text.Fit
            minimumPixelSize: Math.min(12, Math.max(1, stage.cfg.mainSize))
            elide: Text.ElideRight
            color: col.isActive && stage.karaokeFrac >= 0 ? stage.cfg.dimColor : stage.curColor
            font.family: stage.cfg.fontFamily
            font.pixelSize: Math.max(1, stage.cfg.mainSize)
            font.bold: stage.cfg.boldCurrent

            // karaoke: the same text in the bright colour, clipped at the word being sung
            Item {
                visible: col.isActive && stage.karaokeFrac >= 0 && c.lineCount === 1
                height: c.height
                clip: true
                // x of the word being sung: the width of the text before it, measured in the font the
                // line is really drawn in (Fit may have shrunk it); Text has no position lookup
                readonly property real pos: Math.min(1, stage.karaokeFrac) * c.text.length
                readonly property int ci: Math.max(0, Math.min(Math.floor(pos), c.text.length - 1))
                TextMetrics {
                    id: before
                    font.family: c.font.family; font.pixelSize: c.fontInfo.pixelSize; font.bold: c.font.bold
                    text: c.text.substring(0, parent.ci)
                }
                TextMetrics {
                    id: through
                    font.family: c.font.family; font.pixelSize: c.fontInfo.pixelSize; font.bold: c.font.bold
                    text: c.text.substring(0, parent.ci + 1)
                }
                width: c.text.length === 0 ? 0
                       : (c.horizontalAlignment === Text.AlignLeft ? 0
                          : c.horizontalAlignment === Text.AlignRight ? c.width - c.contentWidth
                          : (c.width - c.contentWidth) / 2) + before.advanceWidth
                         + (through.advanceWidth - before.advanceWidth) * (pos - ci)
                Text {
                    width: c.width
                    height: c.height
                    horizontalAlignment: c.horizontalAlignment
                    verticalAlignment: c.verticalAlignment
                    wrapMode: c.wrapMode
                    maximumLineCount: c.maximumLineCount
                    fontSizeMode: c.fontSizeMode
                    minimumPixelSize: c.minimumPixelSize
                    elide: c.elide
                    text: c.text
                    color: stage.curColor
                    font: c.font
                }
            }
        }
        Text {
            id: n
            visible: stage.showSides && stage.cfg.sideSize > 0
            width: parent.width
            horizontalAlignment: stage.textAlign
            elide: Text.ElideRight
            color: stage.cfg.dimColor
            font.family: stage.cfg.fontFamily
            font.pixelSize: Math.max(1, stage.cfg.sideSize)
        }
    }

    Stack { id: a; slotIndex: 0 }
    Stack { id: b; slotIndex: 1 }
}
