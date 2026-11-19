import QtQuick
import QtQuick.Controls as QQC2

// The seek bar, in eleven looks, with the time labels, a time bubble on hover, dragging to seek, the mouse wheel to
// step and a double click to jump. It only shows the position it is given; seeking is a signal.
//  style: 0 none, 1 sleek, 2 minimal, 3 glow pulse, 4 pill, 5 waveform, 6 squiggle, 7 segmented, 8 dotted, 9 capsule,
//  10 time only (11, the ring round the cover, is drawn by Artwork)
Item {
    id: root
    property int style: 1          // 12 is a file of the user's own, shown by CustomProgress instead
    property real position: 0        // seconds
    property real length: 0          // seconds
    property bool playing: false
    property color accent: "#6a8cff"
    property color track: "#33ffffff"
    property color textColor: "white"
    property real beat: 0
    property int labels: 1           // 0 off, 1 elapsed / total, 2 elapsed / -remaining
    property int wheelStep: 5        // seconds, 0 = the wheel does nothing
    property bool doubleClickJump: true
    property string seed: ""         // the song's name: gives the waveform style its shape
    property bool calm: false
    property var chapters: []        // [{start (s), title}] drawn as marks on the bar
    property bool showChapters: true
    property bool seekHover: true    // the time bubble under the pointer
    property bool reactive: true     // the glow style pulses with the beat
    signal seekTo(real sec)
    signal seekBy(real sec)

    readonly property real frac: length > 0 ? Math.max(0, Math.min(1, (dragging ? dragFrac : position / length))) : 0
    property bool dragging: false
    property real dragFrac: 0
    property real hoverFrac: -1
    // the chapter the pointer is over (or the last one before it), for the bubble
    function chapterAt(sec) {
        let c = null
        for (const x of root.chapters) { if (x.start > sec) break; c = x }
        return c
    }

    function fmt(sec) {
        sec = Math.max(0, Math.round(sec))
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
    }
    readonly property string leftLabel: fmt(dragging ? dragFrac * length : position)
    readonly property string rightLabel: labels === 2 ? "-" + fmt(length - (dragging ? dragFrac * length : position)) : fmt(length)
    readonly property bool showLabels: labels > 0 && style !== 0

    implicitHeight: 22
    visible: style !== 0 || false

    // a fixed pseudo-random shape from the song's name, for the waveform look
    function shapeAt(i, n) {
        let h = 7
        for (let k = 0; k < root.seed.length; ++k) h = (h * 31 + root.seed.charCodeAt(k)) >>> 0
        h = (h + i * 2654435761) >>> 0
        h ^= h >>> 15; h = Math.imul(h, 2246822519) >>> 0; h ^= h >>> 13
        const r = (h % 1000) / 1000
        return 0.25 + 0.75 * (0.55 * r + 0.45 * Math.abs(Math.sin(i * 0.37)))
    }

    Text {
        id: left
        visible: root.showLabels
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: root.leftLabel
        color: root.textColor; opacity: 0.8
        font.pixelSize: 11; font.family: "monospace"
        width: root.style === 10 ? parent.width / 2 : implicitWidth
        horizontalAlignment: root.style === 10 ? Text.AlignHCenter : Text.AlignLeft
    }
    Text {
        id: right
        visible: root.showLabels && root.style !== 10
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.rightLabel
        color: root.textColor; opacity: 0.8
        font.pixelSize: 11; font.family: "monospace"
    }
    Text {
        visible: root.style === 10 && root.labels > 0
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: parent.width / 2
        text: root.rightLabel
        color: root.textColor; opacity: 0.8
        font.pixelSize: 11; font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
    }

    // the bar sits between the labels
    Item {
        id: area
        visible: root.style !== 10
        anchors {
            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
            leftMargin: root.showLabels ? left.implicitWidth + 8 : 0
            rightMargin: root.showLabels ? right.implicitWidth + 8 : 0
        }
        height: parent.height

        Canvas {
            id: cv
            anchors.fill: parent
            property real f: root.frac
            property real pulse: root.reactive ? root.beat : 0
            property bool moving: root.playing && !root.calm
            onFChanged: requestPaint()
            onPulseChanged: if (root.style === 3) requestPaint()
            onWidthChanged: requestPaint()
            Connections { target: root; function onStyleChanged() { cv.requestPaint() } function onAccentChanged() { cv.requestPaint() } function onSeedChanged() { cv.requestPaint() } }
            Timer { interval: 90; repeat: true; running: root.style === 6 && cv.moving && root.visible; onTriggered: cv.requestPaint() }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height, mid = h / 2, x = w * f
                ctx.lineCap = "round"
                switch (root.style) {
                case 1: { // sleek: a thin track, a bright fill, a small knob
                    ctx.fillStyle = root.track; ctx.fillRect(0, mid - 1.5, w, 3)
                    ctx.fillStyle = root.accent; ctx.fillRect(0, mid - 1.5, x, 3)
                    ctx.beginPath(); ctx.arc(x, mid, 4.5, 0, 2 * Math.PI); ctx.fill()
                    break }
                case 2: { // minimal: a hairline and nothing else
                    ctx.fillStyle = root.track; ctx.fillRect(0, mid - 0.5, w, 1)
                    ctx.fillStyle = root.accent; ctx.fillRect(0, mid - 0.5, x, 1)
                    break }
                case 3: { // glow pulse: the fill glows more with the beat
                    ctx.fillStyle = root.track; ctx.fillRect(0, mid - 2, w, 4)
                    ctx.shadowColor = root.accent; ctx.shadowBlur = 6 + 14 * pulse
                    ctx.fillStyle = root.accent; ctx.fillRect(0, mid - 2, x, 4)
                    ctx.beginPath(); ctx.arc(x, mid, 5 + 2 * pulse, 0, 2 * Math.PI); ctx.fill()
                    break }
                case 4: { // pill: a thick rounded bar
                    const th = Math.min(h, 10), r = th / 2
                    ctx.fillStyle = root.track
                    ctx.beginPath(); ctx.arc(r, mid, r, Math.PI / 2, 1.5 * Math.PI); ctx.arc(w - r, mid, r, 1.5 * Math.PI, Math.PI / 2); ctx.closePath(); ctx.fill()
                    if (x > 0) {
                        const fw = Math.max(th, x)
                        ctx.fillStyle = root.accent
                        ctx.beginPath(); ctx.arc(r, mid, r, Math.PI / 2, 1.5 * Math.PI); ctx.arc(fw - r, mid, r, 1.5 * Math.PI, Math.PI / 2); ctx.closePath(); ctx.fill()
                    }
                    break }
                case 5: { // waveform: bars of a fixed shape, the played part bright
                    const bw = 3, gap = 2, n = Math.max(4, Math.floor((w + gap) / (bw + gap)))
                    for (let i = 0; i < n; ++i) {
                        const bh = Math.max(3, h * 0.9 * root.shapeAt(i, n)), bx = i * (bw + gap)
                        ctx.fillStyle = (bx + bw / 2) <= x ? root.accent : root.track
                        ctx.fillRect(bx, mid - bh / 2, bw, bh)
                    }
                    break }
                case 6: { // squiggle: a wavy line for the played part, straight for the rest
                    const ph = cv.moving ? Date.now() / 220 : 0, amp = Math.min(4, h / 3)
                    ctx.lineWidth = 2.5
                    ctx.strokeStyle = root.track; ctx.beginPath(); ctx.moveTo(x, mid); ctx.lineTo(w, mid); ctx.stroke()
                    ctx.strokeStyle = root.accent; ctx.beginPath()
                    for (let px = 0; px <= x; px += 2) { const y = mid + Math.sin(px / 5 - ph) * amp; if (px === 0) ctx.moveTo(px, y); else ctx.lineTo(px, y) }
                    ctx.stroke()
                    break }
                case 7: { // segmented: separate blocks
                    const sw = 10, gap = 3, n = Math.max(3, Math.floor((w + gap) / (sw + gap))), th = Math.min(h, 8)
                    for (let i = 0; i < n; ++i) { ctx.fillStyle = (i + 0.5) / n <= f ? root.accent : root.track; ctx.fillRect(i * (sw + gap), mid - th / 2, sw, th) }
                    break }
                case 8: { // dotted: a row of dots
                    const step = 9, n = Math.max(3, Math.floor(w / step))
                    for (let i = 0; i < n; ++i) { ctx.fillStyle = (i + 0.5) / n <= f ? root.accent : root.track; ctx.beginPath(); ctx.arc(i * step + step / 2, mid, i / n <= f ? 2.6 : 2, 0, 2 * Math.PI); ctx.fill() }
                    break }
                case 9: { // capsule: an outlined capsule that fills from the left
                    const th = Math.min(h - 2, 14), r = th / 2, y0 = mid - r
                    ctx.lineWidth = 1.5; ctx.strokeStyle = root.accent
                    ctx.beginPath(); ctx.arc(r + 1, mid, r, Math.PI / 2, 1.5 * Math.PI); ctx.arc(w - r - 1, mid, r, 1.5 * Math.PI, Math.PI / 2); ctx.closePath(); ctx.stroke()
                    ctx.save(); ctx.beginPath(); ctx.rect(0, y0 - 1, x, th + 2); ctx.clip()
                    ctx.fillStyle = root.accent
                    ctx.beginPath(); ctx.arc(r + 1, mid, r, Math.PI / 2, 1.5 * Math.PI); ctx.arc(w - r - 1, mid, r, 1.5 * Math.PI, Math.PI / 2); ctx.closePath(); ctx.fill()
                    ctx.restore()
                    break }
                }
                // the hover marker
                if (root.hoverFrac >= 0 && !root.dragging) { ctx.fillStyle = "#88ffffff"; ctx.fillRect(w * root.hoverFrac - 0.5, mid - h * 0.3, 1, h * 0.6) }
            }
        }

        // chapter marks: a short tick at the start of each chapter
        Repeater {
            model: root.showChapters && root.length > 0 && root.style !== 10 ? root.chapters : []
            Rectangle {
                required property var modelData
                visible: modelData.start > 0
                x: area.width * modelData.start / root.length - 0.5
                y: area.height / 2 - 6
                width: 1.5; height: 12
                color: root.textColor; opacity: 0.55
            }
        }

        // time under the pointer
        Rectangle {
            visible: root.seekHover && root.hoverFrac >= 0 && root.length > 0 && root.style !== 10
            x: Math.max(0, Math.min(area.width - width, area.width * (root.dragging ? root.dragFrac : root.hoverFrac) - width / 2))
            y: -height - 2
            width: bubble.implicitWidth + 10; height: bubble.implicitHeight + 4
            radius: 4; color: "#cc111111"
            Text { id: bubble; anchors.centerIn: parent; color: "white"; font.pixelSize: 11; font.family: "monospace"
                   text: root.fmt((root.dragging ? root.dragFrac : root.hoverFrac) * root.length)
                         + (root.showChapters && root.chapterAt((root.dragging ? root.dragFrac : root.hoverFrac) * root.length)
                            ? "  " + root.chapterAt((root.dragging ? root.dragFrac : root.hoverFrac) * root.length).title : "") }
        }

        MouseArea {
            id: ma
            anchors.fill: parent; anchors.topMargin: -4; anchors.bottomMargin: -4
            hoverEnabled: true
            enabled: root.length > 0
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: (m) => { root.hoverFrac = Math.max(0, Math.min(1, m.x / width)); if (pressed) { root.dragging = true; root.dragFrac = root.hoverFrac } }
            onExited: { if (!pressed) root.hoverFrac = -1 }
            onPressed: (m) => { root.dragFrac = Math.max(0, Math.min(1, m.x / width)); root.dragging = true }
            onReleased: { if (root.dragging) root.seekTo(root.dragFrac * root.length); root.dragging = false }
            onDoubleClicked: (m) => { if (root.doubleClickJump) root.seekBy(m.x < width / 2 ? -10 : 10) }
            onWheel: (w) => { if (root.wheelStep > 0) root.seekBy(w.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep) }
        }
    }
}
