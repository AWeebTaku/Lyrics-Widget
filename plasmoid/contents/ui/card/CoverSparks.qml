import QtQuick

// Sparks that fly off the cover's edge on every beat. Cheap: a few dozen dots, drawn only while there are some.
Canvas {
    id: root
    property real beat: 0
    property color accent: "#ffcc66"
    property bool active: true
    property bool calm: false
    property real inset: 0            // the cover's edge is this far in from the canvas edge
    readonly property int maxSparks: 48
    property var sparks: []
    property double last: 0
    property bool armed: true

    onBeatChanged: {
        if (beat < 0.5) armed = true
        else if (armed && beat > 0.95 && active && !calm) {
            armed = false
            const cx = width / 2, cy = height / 2, r = Math.min(width, height) / 2 - inset
            const n = Math.min(maxSparks - sparks.length, 14)
            for (let i = 0; i < n; ++i) {
                const a = Math.random() * 2 * Math.PI, sp = 40 + Math.random() * 90
                sparks.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: 1, r: 1 + Math.random() * 1.8 })
            }
            last = Date.now()
            run.start()
        }
    }
    Timer {
        id: run
        interval: 33; repeat: true
        onTriggered: {
            const t = Date.now(), dt = Math.min(0.06, (t - root.last) / 1000)
            root.last = t
            for (const s of root.sparks) { s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt * 1.4 }
            root.sparks = root.sparks.filter(s => s.life > 0)
            if (root.sparks.length === 0) stop()
            root.requestPaint()
        }
    }
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = root.accent
        for (const s of sparks) {
            ctx.globalAlpha = Math.max(0, s.life)
            ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, 2 * Math.PI); ctx.fill()
        }
    }
}
