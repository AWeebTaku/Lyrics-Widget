// Visualizer styles beyond bars / wave / blocks. Each draws one frame on a Canvas 2D context from the canvas
// object `c`: c.width / c.height (px), c.values and c.peaks (one px height per bar, 0..height), c.barCount,
// c.barWidth, c.spacing, c.blockHeight, c.blockSpacing, c.gradient (the bar colors), c.colors (a color list),
// c.bass / c.beat (0..1), c.reduced (no motion). Bars grow from the bottom; the item is rotated for other sides.

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
function val(c, i) { return clamp(c.values[i] || 0, 0, c.height) }
function pk(c, i) { return clamp(c.peaks && c.peaks.length > i ? c.peaks[i] : val(c, i), 0, c.height) }
function colorAt(c, i) {
    const n = c.colors ? c.colors.length : 0
    return n > 0 ? c.colors[i % n] : "white"
}
function now() { return Date.now() }

// the color for a level (0..1) when "color by level" is on: low levels take the first color, loud ones the last
function levelColor(c, frac) {
    const n = c.colors ? c.colors.length : 0
    return n > 0 ? c.colors[Math.max(0, Math.min(n - 1, Math.round(frac * (n - 1))))] : "white"
}

// x of bar i for the bar-like styles (bars have a width and a gap) and for the line-like ones (points spread over the width)
function barX(c, i) { return i * (c.barWidth + c.spacing) + c.barWidth / 2 }
function pointX(c, i) { return c.barCount > 1 ? i * c.width / (c.barCount - 1) : c.width / 2 }

// ---- bars with a cap that falls slowly after each peak
function peakBars(ctx, c) {
    ctx.lineWidth = c.barWidth
    ctx.lineCap = "butt"
    ctx.strokeStyle = c.gradient
    ctx.fillStyle = c.gradient
    const cap = Math.max(2, Math.round(c.barWidth / 2))
    for (let i = 0; i < c.barCount; ++i) {
        const x = barX(c, i), v = Math.max(1, val(c, i))
        if (c.byLevel) { const col = levelColor(c, v / c.height); ctx.strokeStyle = col; ctx.fillStyle = col }
        ctx.beginPath(); ctx.moveTo(x, c.height); ctx.lineTo(x, c.height - v); ctx.stroke()
        ctx.fillRect(x - c.barWidth / 2, c.height - pk(c, i) - cap - 1, c.barWidth, cap)
    }
}

// ---- stacked LED segments: green at the bottom to red at the top, the peak segment stays lit.
// Qt's canvas has no dashed lines, so a column is one solid line under a green-to-red gradient and the gaps between
// segments are erased afterwards, one full-width strip per row: a few dozen canvas calls instead of one per segment,
// which is what keeps it cheap. The unlit part is a faint rack without gaps.
function ledMeter(ctx, c) {
    const step = c.blockHeight + c.blockSpacing
    const rows = Math.max(1, Math.floor((c.height + c.blockSpacing) / step))
    const g = ctx.createLinearGradient(0, c.height, 0, 0)
    g.addColorStop(0, "hsl(120,85%,50%)"); g.addColorStop(0.55, "hsl(60,90%,50%)"); g.addColorStop(1, "hsl(0,85%,52%)")
    ctx.lineWidth = c.barWidth
    ctx.lineCap = "butt"
    ctx.globalAlpha = 0.1                              // the unlit rack: plain faint columns, no gaps
    ctx.strokeStyle = "white"
    for (let i = 0; i < c.barCount; ++i) {
        ctx.beginPath(); ctx.moveTo(barX(c, i), c.height); ctx.lineTo(barX(c, i), c.height - rows * step + c.blockSpacing); ctx.stroke()
    }
    ctx.globalAlpha = 1
    ctx.strokeStyle = g
    for (let i = 0; i < c.barCount; ++i) {
        const lit = Math.round(val(c, i) / c.height * rows)
        if (lit > 0) { ctx.beginPath(); ctx.moveTo(barX(c, i), c.height); ctx.lineTo(barX(c, i), c.height - lit * step + c.blockSpacing); ctx.stroke() }
    }
    let top = 0
    for (let i = 0; i < c.barCount; ++i)
        top = Math.max(top, Math.round(val(c, i) / c.height * rows))
    ctx.globalCompositeOperation = "destination-out"
    for (let r = 0; r < Math.min(rows, top + 1); ++r)   // only as high as anything is lit
        ctx.fillRect(0, c.height - (r + 1) * step, c.width, c.blockSpacing)
    ctx.globalCompositeOperation = "source-over"
    ctx.fillStyle = g
    for (let i = 0; i < c.barCount; ++i) {          // the peak segment
        const cap = Math.min(rows - 1, Math.round(pk(c, i) / c.height * rows))
        ctx.fillRect(barX(c, i) - c.barWidth / 2, c.height - (cap + 1) * c.blockHeight - cap * c.blockSpacing, c.barWidth, c.blockHeight)
    }
}

// ---- a smooth filled ridge; a fainter ridge behind it follows the peaks
function ridge(ctx, c, getter, fill, stroke, alpha) {
    const n = c.barCount
    if (n < 2) return
    const ys = []
    for (let i = 0; i < n; ++i) ys.push(c.height - getter(c, i))
    ctx.globalAlpha = alpha
    ctx.beginPath()
    ctx.moveTo(0, c.height)
    ctx.lineTo(0, ys[0])
    for (let i = 0; i < n - 1; ++i) {
        const x0 = pointX(c, i), x1 = pointX(c, i + 1), xm = (x0 + x1) / 2, ym = (ys[i] + ys[i + 1]) / 2
        ctx.quadraticCurveTo(x0, ys[i], xm, ym)
    }
    ctx.lineTo(c.width, ys[n - 1])
    ctx.lineTo(c.width, c.height)
    ctx.closePath()
    if (fill) { ctx.fillStyle = c.gradient; ctx.fill() }
    if (stroke) { ctx.strokeStyle = c.gradient; ctx.lineWidth = Math.max(1, c.barWidth); ctx.stroke() }
    ctx.globalAlpha = 1
}
function mountain(ctx, c) {
    ridge(ctx, c, pk, true, false, 0.25)
    ridge(ctx, c, val, true, true, 0.75)
}

// ---- oscilloscope: a trace whose swing follows each band; a wide faint pass under a thin bright one gives the glow
function scope(ctx, c) {
    const n = c.barCount
    if (n < 2) return
    const phase = c.reduced ? 0 : now() / 260
    const mid = c.height / 2
    const ys = []
    for (let i = 0; i < n; ++i) ys.push(mid - val(c, i) / 2 * Math.sin(i * 0.9 + phase))
    const trace = (w, a) => {
        ctx.globalAlpha = a
        ctx.lineWidth = w
        ctx.lineJoin = "round"
        ctx.strokeStyle = c.gradient
        ctx.beginPath()
        ctx.moveTo(pointX(c, 0), ys[0])
        for (let i = 1; i < n - 1; ++i)
            ctx.quadraticCurveTo(pointX(c, i), ys[i], (pointX(c, i) + pointX(c, i + 1)) / 2, (ys[i] + ys[i + 1]) / 2)
        ctx.lineTo(pointX(c, n - 1), ys[n - 1])
        ctx.stroke()
    }
    trace(Math.max(3, c.barWidth * 3), 0.2)
    trace(Math.max(1, c.barWidth), 1)
    ctx.globalAlpha = 0.2
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(c.width, mid); ctx.stroke()
    ctx.globalAlpha = 1
}

// ---- a grid of lit pixels from the bottom, with the peak pixel above each column: solid lines, gaps erased per row
function pixelMatrix(ctx, c) {
    const cell = c.blockHeight + c.blockSpacing
    const rows = Math.max(1, Math.floor(c.height / cell))
    const side = Math.max(1, Math.min(c.barWidth, c.blockHeight))
    const gap = cell - side
    ctx.strokeStyle = c.gradient
    ctx.fillStyle = c.gradient
    ctx.lineWidth = side
    ctx.lineCap = "butt"
    for (let i = 0; i < c.barCount; ++i) {
        const lit = Math.round(val(c, i) / c.height * rows)
        if (lit > 0) { ctx.beginPath(); ctx.moveTo(barX(c, i), c.height); ctx.lineTo(barX(c, i), c.height - lit * cell + gap / 2); ctx.stroke() }
    }
    if (gap > 0) {
        ctx.globalCompositeOperation = "destination-out"
        for (let k = 0; k <= rows; ++k)
            ctx.fillRect(0, c.height - k * cell - gap / 2, c.width, gap)
        ctx.globalCompositeOperation = "source-over"
    }
    for (let i = 0; i < c.barCount; ++i) {
        const cap = Math.min(rows - 1, Math.round(pk(c, i) / c.height * rows))
        ctx.fillRect(barX(c, i) - side / 2, c.height - (cap + 1) * cell + gap / 2, side, side)
    }
}

// ---- one dot per band riding the level, with a faint stalk to the floor
function floatingDots(ctx, c) {
    const rad = Math.max(2, c.barWidth)
    for (let i = 0; i < c.barCount; ++i) {
        const x = barX(c, i), y = c.height - rad - val(c, i) * (c.height - 2 * rad) / c.height
        ctx.globalAlpha = 0.18
        ctx.strokeStyle = colorAt(c, i)
        ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(x, c.height); ctx.lineTo(x, y); ctx.stroke()
        ctx.globalAlpha = 1
        ctx.fillStyle = c.byLevel ? levelColor(c, val(c, i) / c.height) : c.gradient
        ctx.beginPath(); ctx.arc(x, y, rad, 0, 2 * Math.PI); ctx.fill()
        ctx.globalAlpha = 0.6
        ctx.beginPath(); ctx.arc(x, c.height - rad - pk(c, i) * (c.height - 2 * rad) / c.height, Math.max(1, rad / 2), 0, 2 * Math.PI); ctx.fill()
        ctx.globalAlpha = 1
    }
}

// ---- a thin polyline with a small square marker on every point
function techLine(ctx, c) {
    const n = c.barCount
    if (n < 2) return
    ctx.strokeStyle = c.gradient
    ctx.fillStyle = c.gradient
    ctx.lineWidth = Math.max(1, Math.round(c.barWidth / 2))
    ctx.lineJoin = "miter"
    ctx.beginPath()
    for (let i = 0; i < n; ++i) {
        const x = pointX(c, i), y = c.height - val(c, i)
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
    }
    ctx.stroke()
    const m = Math.max(3, c.barWidth * 2)
    const every = Math.max(1, Math.round(n / 40))
    for (let i = 0; i < n; i += every)
        ctx.fillRect(pointX(c, i) - m / 2, c.height - val(c, i) - m / 2, m, m)
}

// ---- spokes from a center that turns slowly
function radialBurst(ctx, c) {
    const cx = c.width / 2, cy = c.height / 2, r0 = Math.min(c.width, c.height) * 0.16
    const rMax = Math.min(c.width, c.height) / 2 - 1
    const spin = c.reduced ? 0 : now() / 9000
    ctx.strokeStyle = c.gradient
    ctx.lineWidth = Math.max(1, c.barWidth)
    ctx.lineCap = "round"
    const n = c.barCount
    for (let i = 0; i < n; ++i) {
        const a = spin + i * 2 * Math.PI / n
        const len = r0 + (rMax - r0) * val(c, i) / c.height
        ctx.beginPath()
        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
        ctx.lineTo(cx + Math.cos(a) * len, cy + Math.sin(a) * len)
        ctx.stroke()
    }
}

// ---- an orb that breathes with the bass, a wobbling rim from the bands, and a ring that leaves on each beat
function pulseOrb(ctx, c) {
    const cx = c.width / 2, cy = c.height / 2, half = Math.min(c.width, c.height) / 2
    const r = half * (0.38 + 0.22 * c.bass)
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
    g.addColorStop(0, colorAt(c, 0)); g.addColorStop(1, colorAt(c, 1))
    ctx.globalAlpha = 0.85
    ctx.fillStyle = g
    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill()
    ctx.globalAlpha = 1
    const n = Math.max(8, c.barCount)
    ctx.strokeStyle = c.gradient
    ctx.lineWidth = Math.max(1, c.barWidth)
    ctx.beginPath()
    for (let i = 0; i <= n; ++i) {
        const a = i * 2 * Math.PI / n, rr = r * (1.08 + 0.3 * val(c, i % c.barCount) / c.height)
        const x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
    }
    ctx.stroke()
    if (c.beat > 0.02) {
        ctx.globalAlpha = c.beat
        ctx.lineWidth = Math.max(1, c.barWidth / 2)
        ctx.beginPath(); ctx.arc(cx, cy, r + (half - r) * (1 - c.beat), 0, 2 * Math.PI); ctx.stroke()
        ctx.globalAlpha = 1
    }
}

// ---- a band across the middle that swells with each band; the center line drifts like cloth
function ribbon(ctx, c) {
    const n = c.barCount
    if (n < 2) return
    const t = c.reduced ? 0 : now() / 900
    const mid = c.height / 2
    const curv = c.ribbonCurve === undefined ? 1 : c.ribbonCurve, full = c.ribbonFull === undefined ? 1 : c.ribbonFull
    const top = [], bot = []
    for (let i = 0; i < n; ++i) {
        const sway = Math.sin(i * 0.35 * curv + t) * c.height * 0.08 * curv
        const half = Math.max(1, val(c, i) / 2 * full)
        top.push(mid + sway - half); bot.push(mid + sway + half)
    }
    ctx.beginPath()
    ctx.moveTo(pointX(c, 0), top[0])
    for (let i = 1; i < n; ++i) ctx.lineTo(pointX(c, i), top[i])
    for (let i = n - 1; i >= 0; --i) ctx.lineTo(pointX(c, i), bot[i])
    ctx.closePath()
    ctx.globalAlpha = 0.7
    ctx.fillStyle = c.gradient
    ctx.fill()
    ctx.globalAlpha = 1
    ctx.strokeStyle = c.gradient
    ctx.lineWidth = Math.max(1, c.barWidth / 2)
    ctx.stroke()
}

// ---- particles: state lives here between frames; spawned on beats, capped, and off under reduced motion
const MAX_PARTICLES = 80
let parts = []
let lastT = 0
function stepParticles(c, gravity) {
    const t = now(), dt = Math.min(0.05, (t - lastT) / 1000)
    lastT = t
    if (c.reduced) { parts = []; return }
    if (c.beat > 0.95 && parts.length < MAX_PARTICLES) {
        const k = Math.min(MAX_PARTICLES - parts.length, 6 + Math.round(c.bass * 10))
        for (let j = 0; j < k; ++j) {
            const i = Math.floor(Math.random() * c.barCount)
            parts.push({ x: barX(c, i), y: c.height - pk(c, i), vx: (Math.random() - 0.5) * 60, vy: -(40 + Math.random() * 120) * (0.4 + c.bass),
                         life: 1, c: colorAt(c, i), r: 1 + Math.random() * Math.max(1, c.barWidth) })
        }
    }
    for (const p of parts) {
        p.x += p.vx * dt; p.y += p.vy * dt
        p.vy += (gravity ? 420 : 30) * dt
        if (gravity && p.y > c.height - p.r) { p.y = c.height - p.r; p.vy *= -0.55; p.vx *= 0.8 }
        p.life -= dt * (gravity ? 0.45 : 0.9)
    }
    parts = parts.filter(p => p.life > 0)
}
function particles(ctx, c, gravity) {
    stepParticles(c, gravity)
    // faint bars underneath keep the music visible between beats
    ctx.globalAlpha = 0.35
    ctx.strokeStyle = c.gradient
    ctx.lineWidth = Math.max(1, c.barWidth)
    for (let i = 0; i < c.barCount; ++i) {
        ctx.beginPath(); ctx.moveTo(barX(c, i), c.height); ctx.lineTo(barX(c, i), c.height - Math.max(1, val(c, i))); ctx.stroke()
    }
    for (const p of parts) {
        ctx.globalAlpha = Math.max(0, p.life)
        ctx.fillStyle = p.c
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 2 * Math.PI); ctx.fill()
    }
    ctx.globalAlpha = 1
}
function sparkles(ctx, c) { particles(ctx, c, false) }
function gravitySparks(ctx, c) { particles(ctx, c, true) }

// ---- a ring of spokes around a hole (the lyrics or the cover sit in it); turns slowly, breathes with the bass
function orbitRing(ctx, c) {
    const cx = c.width / 2, cy = c.height / 2, half = Math.min(c.width, c.height) / 2
    const r0 = half * (0.56 + 0.05 * c.bass), rMax = half - 1
    const spin = c.reduced || c.spin === false ? 0 : now() / 14000
    const n = c.barCount
    ctx.lineCap = "round"
    ctx.lineWidth = Math.max(1, c.barWidth)
    ctx.strokeStyle = c.gradient
    for (let i = 0; i < n; ++i) {
        const a = spin + i * 2 * Math.PI / n
        const len = r0 + (rMax - r0) * Math.max(0.04, val(c, i) / c.height)
        ctx.beginPath()
        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
        ctx.lineTo(cx + Math.cos(a) * len, cy + Math.sin(a) * len)
        ctx.stroke()
    }
    ctx.globalAlpha = 0.35
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.arc(cx, cy, r0 - 4, 0, 2 * Math.PI); ctx.stroke()
    ctx.globalAlpha = 1
}

// ---- stereo scope: left against right (a Lissajous figure). The data is cava's stereo waveform: the left channel's
// samples, then the right's. In mono it is a line along the diagonal.
function stereoScope(ctx, c) {
    const n = Math.floor(c.barCount / 2)
    const cx = c.width / 2, cy = c.height / 2, sx = Math.min(c.width, c.height) * 0.9, sy = c.height * 0.9
    if (n < 2) return
    const point = i => {
        const l = (c.values[i] || 0) / c.height - 0.5, r = (c.values[n + i] || 0) / c.height - 0.5
        return [cx + l * sx, cy - r * sy]
    }
    ctx.lineJoin = "round"
    ctx.strokeStyle = c.gradient
    const trace = (w, a) => {
        ctx.globalAlpha = a
        ctx.lineWidth = w
        ctx.beginPath()
        const p0 = point(0)
        ctx.moveTo(p0[0], p0[1])
        for (let i = 1; i < n; ++i) { const p = point(i); ctx.lineTo(p[0], p[1]) }
        ctx.stroke()
    }
    trace(Math.max(3, c.barWidth * 3), 0.18)
    trace(Math.max(1, c.barWidth / 2), 1)
    ctx.globalAlpha = 0.2
    ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(cx - sx / 2, cy + sy / 2); ctx.lineTo(cx + sx / 2, cy - sy / 2); ctx.stroke()   // mono line
    ctx.globalAlpha = 1
}

// ---- CRT oscilloscope: a green phosphor trace with a glow, a faint graticule, scanlines and darkened corners
function crtScope(ctx, c) {
    const n = c.barCount
    if (n < 2) return
    const t = c.reduced ? 0 : now() / 260
    const mid = c.height / 2
    const flicker = c.reduced ? 1 : 0.94 + 0.06 * Math.sin(now() / 53)
    // graticule
    ctx.strokeStyle = "#6dff9a"; ctx.globalAlpha = 0.12; ctx.lineWidth = 1
    for (let i = 1; i < 8; ++i) { const x = c.width * i / 8; ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, c.height); ctx.stroke() }
    for (let i = 1; i < 4; ++i) { const y = c.height * i / 4; ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(c.width, y); ctx.stroke() }
    const ys = []
    for (let i = 0; i < n; ++i) ys.push(mid - val(c, i) / 2 * Math.sin(i * 0.9 + t))
    const trace = (w, a) => {
        ctx.globalAlpha = a * flicker; ctx.lineWidth = w; ctx.lineJoin = "round"; ctx.strokeStyle = "#6dff9a"
        ctx.beginPath(); ctx.moveTo(pointX(c, 0), ys[0])
        for (let i = 1; i < n - 1; ++i)
            ctx.quadraticCurveTo(pointX(c, i), ys[i], (pointX(c, i) + pointX(c, i + 1)) / 2, (ys[i] + ys[i + 1]) / 2)
        ctx.lineTo(pointX(c, n - 1), ys[n - 1]); ctx.stroke()
    }
    trace(Math.max(6, c.barWidth * 5), 0.12)
    trace(Math.max(3, c.barWidth * 2.5), 0.28)
    trace(Math.max(1, c.barWidth), 1)
    // scanlines
    ctx.globalAlpha = 0.22; ctx.fillStyle = "#000000"
    for (let y = 0; y < c.height; y += 3) ctx.fillRect(0, y, c.width, 1)
    // darkened corners
    const g = ctx.createRadialGradient(c.width / 2, c.height / 2, Math.min(c.width, c.height) * 0.35, c.width / 2, c.height / 2, Math.max(c.width, c.height) * 0.7)
    g.addColorStop(0, "rgba(0,0,0,0)"); g.addColorStop(1, "rgba(0,0,0,0.55)")
    ctx.globalAlpha = 1; ctx.fillStyle = g; ctx.fillRect(0, 0, c.width, c.height)
}

// ---- silk ribbon: a bundle of thin filaments that twist together; the bass thickens the bundle, the level of each band
// bends it, and the beat lights it up. ribbonCurve / ribbonFull set how much it sways and how full it is.
function silkRibbon(ctx, c) {
    const n = c.barCount
    if (n < 2) return
    const t = c.reduced ? 0 : now() / 1100
    const mid = c.height / 2
    const curv = c.ribbonCurve === undefined ? 1 : c.ribbonCurve, full = c.ribbonFull === undefined ? 1 : c.ribbonFull
    const F = 14
    ctx.lineCap = "round"; ctx.lineJoin = "round"
    ctx.strokeStyle = c.gradient
    for (let k = 0; k < F; ++k) {
        const u = (k / (F - 1) - 0.5) * 2                 // -1 .. 1 across the bundle
        ctx.globalAlpha = 0.28 + 0.5 * (1 - Math.abs(u) * 0.6) + 0.2 * c.beat
        ctx.lineWidth = Math.max(0.8, c.barWidth * 0.5)
        ctx.beginPath()
        for (let i = 0; i < n; ++i) {
            const x = pointX(c, i)
            const env = Math.max(1, val(c, i) / 2) * full * (0.55 + 0.9 * c.bass)
            const y = mid + Math.sin(i * 0.28 * curv + t + k * 0.35) * c.height * 0.09 * curv + u * env * Math.cos(k * 0.5 + i * 0.05 + t * 0.7)
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }
    ctx.globalAlpha = 1
}
