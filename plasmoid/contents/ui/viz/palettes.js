.pragma library
// Color sets for the visualizer's color modes. Colors are "#rrggbb" strings (what the color list takes).

const palettes = [
    { name: "Dusk",    colors: ["#ff8a5c", "#d6457f", "#6a2c91"] },
    { name: "Lagoon",  colors: ["#2de2c8", "#2b93e0", "#3446b8"] },
    { name: "Meadow",  colors: ["#d4f25f", "#52c46f", "#1f7d66"] },
    { name: "Cinder",  colors: ["#ffd37a", "#f0793d", "#9c2430"] },
    { name: "Orchid",  colors: ["#f5b3ff", "#a45ce8", "#4a2a9e"] },
    { name: "Frost",   colors: ["#ffffff", "#a9dcff", "#4f8fe0"] },
    { name: "Candy",   colors: ["#ff9fcf", "#ffd27a", "#7fe3ff"] },
    { name: "Ink",     colors: ["#e8e8ee", "#8d93a8", "#3b4056"] }
]

function hex2(n) { const s = Math.round(Math.max(0, Math.min(255, n))).toString(16); return s.length < 2 ? "0" + s : s }
function hsl(h, s, l) {
    h = ((h % 1) + 1) % 1
    const a = s * Math.min(l, 1 - l)
    const f = n => { const k = (n + h * 12) % 12; return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)) }
    return "#" + hex2(f(0) * 255) + hex2(f(8) * 255) + hex2(f(4) * 255)
}

// `stops` colors spread round the color wheel, starting at hue `offset` (0..1)
function rainbow(offset, stops) {
    const out = []
    for (let i = 0; i < stops; ++i)
        out.push(hsl(offset + i / stops, 0.75, 0.58))
    return out
}

function paletteColors(i) {
    return palettes[Math.max(0, Math.min(palettes.length - 1, i))].colors
}
