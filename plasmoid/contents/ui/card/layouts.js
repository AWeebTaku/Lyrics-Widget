.pragma library
// Where each part of the card goes, for every layout, from the widget's size. Pure functions (no QML), checked by
// tests/layouts.test.js. A rect is {x, y, w, h}; a part that a layout does not show is null.

const modes = [
    { id: 0, name: "Lyrics only" },
    { id: 1, name: "Visualizer only" },
    { id: 2, name: "Classic" },
    { id: 3, name: "Mirrored" },
    { id: 4, name: "Inline" },
    { id: 5, name: "Hero wave" },
    { id: 6, name: "Stacked" },
    { id: 7, name: "Orbit" },
    { id: 8, name: "Poster" },
    { id: 9, name: "Slim strip" },
    { id: 10, name: "Compact (no art)" },
    { id: 11, name: "Icon (cover in a progress ring)" }
]

// the size each layout is drawn for, [w, h] in px: what a panel is asked for, and what the card shrinks or grows from
const natural = [[760, 220], [480, 200], [420, 160], [420, 160], [440, 120], [440, 200], [320, 360], [340, 380], [440, 220], [520, 64], [340, 110], [64, 64]]
function naturalSize(mode) { return natural[Math.max(0, Math.min(natural.length - 1, mode))] }

// the smallest the widget can be before a layout is cramped (what roomForCard in main.qml also uses)
function minSize(mode) { const n = naturalSize(mode); return [Math.round(n[0] * 0.8), Math.round(n[1] * 0.8)] }
// whether a layout needs the widget resized: W, H the widget's size in px (0 = free to drag, so never "too small")
function needsResize(mode, W, H) {
    if (mode < 2) return false
    const m = minSize(mode)
    return (W > 0 && W < m[0]) || (H > 0 && H < m[1])
}
function sizeText(mode) { const n = naturalSize(mode); return n[0] + " x " + n[1] + " px" }

// where the two hover buttons (look for other lyrics, lyrics library) and the sync nudge row (-1s ... +1s) sit for a layout:
// beside and under the lyrics, so they never cover the card's own buttons or seek bar
function placeExtras(o, W, H) {
    const L = o.lyrics
    o.tools = null; o.toolsRow = false; o.nudge = null
    if (!L || L.h <= 0 || L.w < 120) return
    o.toolsRow = L.h < 60                                  // a short lyric area: the two buttons side by side
    const tw = o.toolsRow ? 60 : 26, th = o.toolsRow ? 26 : 56
    // the first spot along the lyrics' right edge that the card's own buttons and seek bar do not take
    const hit = (a, b) => b && a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
    const x = L.x + L.w - tw - 6
    const ys = [L.y + 4, o.controls ? o.controls.y + o.controls.h + 4 : L.y + 4, L.y + (L.h - th) / 2, L.y + L.h - th - 4]
    let t = null
    for (const y of ys) {
        const c = r(x, y, tw, th)
        if (c.y >= L.y && c.y + c.h <= L.y + L.h && !hit(c, o.controls) && !hit(c, o.progress) && !hit(c, o.info)) { t = c; break }
    }
    o.tools = t
    o.nudge = r(L.x, L.y + L.h - 22, L.w, 22)
}

function r(x, y, w, h) { return { x: Math.round(x), y: Math.round(y), w: Math.max(0, Math.round(w)), h: Math.max(0, Math.round(h)) } }

// W, H: the widget in px; art: the artwork size setting (px); pad: outer margin
function layout(mode, W, H, art, pad, opts) {
    pad = pad === undefined ? 14 : pad
    opts = opts || {}
    const gap = 10
    const o = { art: null, info: null, controls: null, progress: null, lyrics: r(0, 0, W, H), clock: null,
                vizFill: false, orbit: false, headline: false, ring: false, vizForced: false, controlsAlign: "center", tools: null, toolsRow: false, nudge: null, mode: mode }
    const a = Math.max(32, Math.min(art, H - 2 * pad, Math.round(W * 0.45)))
    const ctrlH = 36, progH = 22
    switch (mode) {
    case 0: // lyrics only: today's widget
        break
    case 1: // the visualizer takes everything
        o.lyrics = null; o.vizFill = true
        break
    case 2: case 3: { // art on one side; info on top, lyrics in the middle, controls and progress at the bottom
        const left = mode === 2
        const colX = left ? pad + a + gap : pad
        const colW = W - 2 * pad - a - gap
        // a short card has no room for a row of buttons of its own: they move up beside the title
        const short = H - 2 * pad < 44 + 4 + ctrlH + progH + 34 + 4
        const ctrlW = 130
        o.art = r(left ? pad : W - pad - a, pad, a, a)
        o.info = r(colX, pad, short ? colW - ctrlW - gap : colW, 44)
        o.progress = r(colX, H - pad - progH, colW, progH)
        if (short) {
            o.controls = r(colX + colW - ctrlW, pad + (44 - ctrlH) / 2, ctrlW, ctrlH)
            o.controlsAlign = "right"
            o.lyrics = r(colX, pad + 44 + 4, colW, Math.max(0, H - 2 * pad - 44 - 4 - progH - 4))
        } else {
            o.controls = r(colX, H - pad - progH - ctrlH, colW, ctrlH)
            o.controlsAlign = "left"
            o.lyrics = r(colX, pad + 44 + 4, colW, Math.max(0, H - 2 * pad - 44 - 4 - progH - ctrlH - 4))
        }
        o.vizRect = r(colX, pad, colW, H - 2 * pad - progH - 4)   // the visualizer fills the column beside the cover, above the seek bar
        break
    }
    case 4: { // one row of art, text and controls; progress under it; lyrics below
        const rowH = Math.min(a, 64)
        o.art = r(pad, pad, rowH, rowH)
        const ctrlW = Math.min(150, Math.max(0, W - 2 * pad - rowH - gap) * 0.4)
        o.info = r(pad + rowH + gap, pad, W - 2 * pad - rowH - gap - ctrlW - gap, rowH)
        o.controls = r(W - pad - ctrlW, pad, ctrlW, rowH)
        o.progress = r(pad, pad + rowH + 6, W - 2 * pad, progH)
        o.controlsAlign = "right"
        o.lyrics = r(pad, pad + rowH + 6 + progH + 4, W - 2 * pad, Math.max(0, H - (pad + rowH + 6 + progH + 4) - pad))
        o.vizRect = r(pad, pad + rowH + 6 + progH + 4, W - 2 * pad, Math.max(0, H - (pad + rowH + 6 + progH + 4) - pad))
        break
    }
    case 5: { // the visualizer is the stage; info and progress tuck underneath
        o.vizFill = true
        o.info = r(pad, H - pad - progH - 8 - 40, W - 2 * pad, 40)
        o.progress = r(pad, H - pad - progH, W - 2 * pad, progH)
        o.controls = r(W - pad - 140, pad, 140, ctrlH)
        o.lyrics = r(pad, pad, W - 2 * pad, Math.max(0, H - 2 * pad - 40 - progH - 12))
        break
    }
    case 6: { // art on top, then text, progress, controls, lyrics
        const s = Math.max(32, Math.min(art, Math.round(H * 0.34), W - 2 * pad))
        o.art = r((W - s) / 2, pad, s, s)
        let y = pad + s + 6
        o.info = r(pad, y, W - 2 * pad, 44); y += 44
        o.progress = r(pad, y, W - 2 * pad, progH); y += progH
        o.controls = r(pad, y, W - 2 * pad, ctrlH); y += ctrlH + 4
        o.controlsAlign = "center"
        o.lyrics = r(pad, y, W - 2 * pad, Math.max(0, H - y - pad))
        o.vizRect = r(pad, y, W - 2 * pad, Math.max(0, H - y - pad))
        break
    }
    case 7: { // the art is the center of a ring of bars; lyrics under it
        const d = Math.min(H * 0.62, W - 2 * pad)
        const withTitle = opts.orbitCenter === 1          // the title goes inside the ring too: a smaller cover, higher up
        const s = Math.max(32, Math.min(art, d * (withTitle ? 0.36 : 0.55)))
        o.orbit = true
        o.art = r((W - s) / 2, pad + (withTitle ? d * 0.16 : (d - s) / 2), s, s)
        o.vizRect = r((W - d) / 2, pad, d, d)
        o.info = r(pad, pad + d + 4, W - 2 * pad, 40)
        o.progress = r(pad, H - pad - progH, W - 2 * pad, progH)
        o.controls = r((W - 140) / 2, pad + d - ctrlH, 140, ctrlH)
        o.lyrics = r(pad, pad + d + 4 + 40, W - 2 * pad, Math.max(0, H - (pad + d + 44) - pad - progH - 4))
        break
    }
    case 8: { // the title set big (one or two lines), the music behind it, a clock
        o.headline = true; o.vizFill = true
        const one = opts.posterLines === 1
        o.info = r(pad, H * (one ? 0.24 : 0.18), W - 2 * pad, H * (one ? 0.22 : 0.34))
        o.clock = opts.posterClock === false ? null : r(pad, H - pad - 44, W - 2 * pad, 44)
        o.progress = r(pad, H - pad - (o.clock ? 44 : 0) - progH - 4, W - 2 * pad, progH)
        o.controls = r(W - pad - 140, pad, 140, ctrlH)
        o.lyrics = r(pad, H * 0.54, W - 2 * pad, Math.max(0, H * 0.46 - pad - (o.clock ? 44 : 0) - progH - 8))
        break
    }
    case 9: { // a wide, low strip: art, text, progress, controls, all in one row
        const s = Math.max(24, Math.min(H - 2 * 8, 56))
        o.art = r(8, (H - s) / 2, s, s)
        const ctrlW = Math.min(130, W * 0.18)
        const textW = Math.max(60, (W - 3 * 10 - s - ctrlW) * 0.34)
        o.info = r(8 + s + 10, 0, textW, H)
        o.progress = r(8 + s + 10 + textW + 10, (H - progH) / 2, Math.max(0, W - (8 + s + 10 + textW + 10) - ctrlW - 20), progH)
        o.controls = r(W - 8 - ctrlW, (H - ctrlH) / 2, ctrlW, ctrlH)
        o.lyrics = H >= 90 ? r(8, H, W - 16, 0) : null
        break
    }
    case 11: { // an icon: just the cover, with its progress as a ring
        const s2 = Math.max(16, Math.min(W, H) - 8)
        o.ring = true
        o.art = r((W - s2) / 2, (H - s2) / 2, s2, s2)
        o.lyrics = null
        break
    }
    case 10: { // no art column: info, progress, lyrics
        o.info = r(pad, pad, W - 2 * pad - 140, 44)
        o.controls = r(W - pad - 140, pad, 140, 44)
        o.progress = r(pad, H - pad - progH, W - 2 * pad, progH)
        o.controlsAlign = "right"
        o.lyrics = r(pad, pad + 44 + 4, W - 2 * pad, Math.max(0, H - 2 * pad - 44 - progH - 8))
        o.vizRect = r(pad, pad, W - 2 * pad, H - 2 * pad - progH - 4)
        break
    }
    }
    // the visualizer: in the area the layout gives it (behind the text), or over the whole card; otherwise (no card, or the icon)
    // the Position settings of the Visualizer page place it
    if (mode === 9) o.vizFill = true
    o.vizForced = mode === 5 || mode === 7 || mode === 8     // the music is the point of these: the visualizer is on even if Show: Visualizer is off
    fit(o, W, H)
    placeExtras(o, W, H)
    // without a card the sync row sits a quarter of the way up, as it always did
    if (mode < 2) o.nudge = o.lyrics ? r(0, H - Math.max(8, H * 0.25) - 22, W, 22) : null
    // the background belongs to the card: it covers the whole widget unless the user edits it; the visualizer's place
    o.surface = r(0, 0, W, H)
    o.vizPlace = o.vizFill ? r(0, 0, W, H) : o.vizRect ? o.vizRect : vizBase(W, H, opts.viz)
    applyEdits(o, editsFor(opts.edits, mode), W, H)
    return o
}

// ---- editing a layout: every part can be hidden, moved, resized and made see-through, per layout --------------------------
// The edits are stored as JSON text, {"<layout>": {"<part>": {show, dx, dy, dw, dh, opacity, size}}}: moves and sizes are
// differences from where the layout puts the part, so they follow the card when it is resized. (Layout 1 uses layout 0's.)
const parts = [
    { id: "surface", name: "Background", size: true, opacity: true, key: "surface" },
    { id: "art", name: "Cover", size: true, opacity: true, key: "art", keep: true },     // hidden: the place stays (the ring may still be drawn there)
    { id: "ring", name: "Progress ring round the cover", size: false, opacity: false, flag: true },
    { id: "info", name: "Title and artist", size: true, opacity: true, text: true, key: "info" },
    { id: "controls", name: "Buttons", size: true, opacity: true, key: "controls" },
    { id: "progress", name: "Seek bar", size: true, opacity: true, key: "progress" },
    { id: "clock", name: "Clock", size: true, opacity: true, key: "clock" },
    { id: "lyrics", name: "Lyrics", size: true, opacity: true, key: "lyrics" },
    { id: "viz", name: "Visualizer", size: true, opacity: true, key: "vizPlace" },
    { id: "tools", name: "Corner buttons (other lyrics, library)", size: false, opacity: false, key: "tools" },
    { id: "nudge", name: "Sync row (-1s ... +1s)", size: false, opacity: false, key: "nudge" }
]

// where the visualizer goes when the layout does not place it: a share of the widget on a 3 x 3 grid, plus an offset
// v: {widthPct, heightPct, hAlign, vAlign, offX, offY} (the Position settings of the Visualizer page)
function vizBase(W, H, v) {
    v = v || { widthPct: 100, heightPct: 100, hAlign: 1, vAlign: 1, offX: 0, offY: 0 }
    const w = W * v.widthPct / 100, h = H * v.heightPct / 100
    return r((v.hAlign === 0 ? 0 : v.hAlign === 2 ? W - w : (W - w) / 2) + (v.offX || 0),
             (v.vAlign === 0 ? 0 : v.vAlign === 2 ? H - h : (H - h) / 2) + (v.offY || 0), w, h)
}

function parseEdits(text) {
    if (!text) return {}
    if (typeof text !== "string") return text
    try { const o = JSON.parse(text); return o && typeof o === "object" ? o : {} } catch (e) { return {} }
}
function editsFor(edits, mode) { return parseEdits(edits)[String(mode === 1 ? 0 : mode)] || {} }

// where the corner buttons and the sync row go when a layout leaves them out and the user turns them on
function cornerRects(W, H) { return { tools: r(W - 32, 4, 26, 56), nudge: r(0, H - 26, W, 22) } }
// where a part sits in a layout before any edit, at the layout's own size: the origin the editor measures from
function baseRect(mode, id) {
    const n = naturalSize(mode), p = parts.find(q => q.id === id)
    if (!p || !p.key) return null
    return layout(mode, n[0], n[1], 96, 14, {})[p.key] || cornerRects(n[0], n[1])[id] || null
}

function applyEdits(o, e, W, H) {
    o.hidden = {}
    o.opacity = {}
    o.infoSize = 0
    const corner = cornerRects(W, H)
    for (const part of parts) {
        const ed = e[part.id]
        if (!ed) continue
        if (part.flag) { if (ed.show === false) o.hidden[part.id] = true; continue }     // no place of its own: only on or off
        if (ed.show === false) {
            o.hidden[part.id] = true
            if (!part.keep) o[part.key] = null
            if (part.id === "viz") { o.vizRect = null; o.vizFill = false }
            continue
        }
        let base = o[part.key]
        if (!base && ed.show === true && corner[part.id]) base = corner[part.id]    // shown where the layout would hide it
        if (base) {
            const moved = (ed.dx || ed.dy || ed.dw || ed.dh)
            const n = !moved && base === o[part.key] ? base
                : r(base.x + (ed.dx || 0), base.y + (ed.dy || 0), Math.max(8, base.w + (part.size ? (ed.dw || 0) : 0)), Math.max(8, base.h + (part.size ? (ed.dh || 0) : 0)))
            o[part.key] = n
            if (part.id === "viz") { o.vizRect = n; o.vizFill = false }
        }
        if (part.opacity && ed.opacity !== undefined && ed.opacity !== 100) o.opacity[part.id] = Math.max(0, Math.min(100, ed.opacity)) / 100
        if (part.text && ed.size) o.infoSize = ed.size
    }
    return o
}

// the parts a layout has (the ones the user can edit), with where they sit now; the corner buttons, the sync row, the
// background and the visualizer can always be edited
function partsFor(mode) {
    const n = naturalSize(mode)
    const o = layout(mode, n[0], n[1], 96, 14, {})
    return parts.filter(p => p.flag ? (p.id === "ring" && o.ring) : (o[p.key] || ["tools", "nudge", "surface", "viz"].indexOf(p.id) >= 0))
}
function getEdit(edits, mode, id) { return editsFor(edits, mode)[id] || {} }
// a new JSON text with one field of one part changed (a field at its default is dropped, so the text stays small)
function setEdit(edits, mode, id, field, value) {
    const all = parseEdits(edits)
    const key = String(mode === 1 ? 0 : mode)
    const m = all[key] = all[key] || {}
    const e = m[id] = m[id] || {}
    // undefined/null clears a field; `show: true` is kept (it turns on a part the layout leaves out, like the corner buttons of the icon)
    const isDefault = value === undefined || value === null || (field === "show" ? false : field === "opacity" ? value === 100 : !value)
    if (isDefault) delete e[field]; else e[field] = value
    if (Object.keys(e).length === 0) delete m[id]
    if (Object.keys(m).length === 0) delete all[key]
    return JSON.stringify(all)
}
function resetEdits(edits, mode) {
    const all = parseEdits(edits)
    if (mode === undefined) return "{}"
    delete all[String(mode === 1 ? 0 : mode)]
    return JSON.stringify(all)
}

// a part that does not fit a small widget is cut to the widget, and dropped when too little of it is left
function fit(o, W, H) {
    for (const k of ["art", "info", "controls", "progress", "clock", "vizRect"]) {
        const q = o[k]
        if (!q) continue
        const x = Math.max(0, q.x), y = Math.max(0, q.y)
        const w = Math.min(q.x + q.w, W) - x, h = Math.min(q.y + q.h, H) - y
        o[k] = (k === "art" ? w >= 16 && h >= 16 : w >= 24 && h >= 14) ? { x: x, y: y, w: w, h: h } : null
    }
    if (o.lyrics) {
        const q = o.lyrics
        const x = Math.max(0, q.x), y = Math.max(0, q.y)
        const w = Math.max(0, Math.min(q.x + q.w, W) - x), h = Math.max(0, Math.min(q.y + q.h, H) - y)
        o.lyrics = { x: x, y: Math.min(y, H), w: w, h: h }
    }
    return o
}

// How light a color string is: "#rrggbb" or "#aarrggbb" (Qt puts the alpha first). Returns {lum, alpha}, lum 0..1
// (the usual weighted sum of the channels), or null when it is not a color.
function luminance(str) {
    const m = /^#([0-9a-fA-F]{2})?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/.exec(str || "")
    if (!m) return null
    const lin = h => { const c = parseInt(h, 16) / 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
    return { lum: 0.2126 * lin(m[2]) + 0.7152 * lin(m[3]) + 0.0722 * lin(m[4]), alpha: m[1] ? parseInt(m[1], 16) / 255 : 1 }
}

// What the widget shows is chosen with Show: Lyrics / Visualizer / Card (General). The card's own list is only the
// arrangements. So the layout in force is: the chosen arrangement when the card is on; otherwise the lyrics fill the widget
// (0), or, with the lyrics off and the visualizer on, the visualizer fills it (1).
function effectiveMode(s) {
    return s.showCard ? s.layoutMode : (!s.showLyrics && s.showVisualizer ? 1 : 0)
}
