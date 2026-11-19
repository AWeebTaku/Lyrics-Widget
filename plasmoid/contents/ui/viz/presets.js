.pragma library
// Visualizer presets: a preset is a set of visualizer settings under a name. Built-in ones, ones the user saved (kept
// as JSON in one setting), a text form to share one, and random / daily picks. Pure functions: no QML, so they are
// checked by tests/presets.test.js.

// every setting a preset may carry, with its default and type. A preset always sets all of them (missing ones take
// the default), so applying one never leaves traces of the one before.
const PANEL_RADIUS = 20   // the widget's corner radius default (config/main.xml)
const num = (def, min, max) => ({ def: def, type: "number", min: min, max: max })
const bool = def => ({ def: def, type: "boolean" })
const keys = {
    // visualizer
    visualizerStyle: num(1, 0, 22), orientation: num(1, 0, 3),
    barWidth: num(2, 1, 100), barGap: num(5, 0, 100), blockHeight: num(2, 1, 100), blockSpacing: num(2, 0, 100),
    centeredBars: bool(false), roundedBars: bool(false), fillWave: bool(true), waveMode: num(0, 0, 2),
    vizSmoothing: num(0, 0, 100), vizReleaseMs: num(350, 50, 3000), vizPeakFall: num(40, 0, 100),
    vizBassWeight: num(100, 0, 300), vizTrebleWeight: num(100, 0, 300), vizTaper: bool(false),
    vizColorMode: num(0, 0, 3), vizPalette: num(0, 0, 7), vizRainbowSpeed: num(30, 0, 100),
    vizGlow: num(0, 0, 100), vizGlowColorMode: num(0, 0, 2), vizSpacing: num(0, 0, 2), vizColorByLevel: bool(false),
    showVisualizer: bool(false),
    // effects
    lyricPulse: num(0, 0, 100), panelGlow: num(0, 0, 100), ambientGlow: num(0, 0, 100), autoContrast: bool(false),
    reducedMotion: bool(false), batterySaver: bool(false),
    // the card
    showCard: bool(false), showLyrics: bool(true), layoutMode: num(2, 2, 11), cardSurface: num(0, 0, 6),
    panelColor: { def: "#a0101018", type: "string", pattern: /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/ },
    surfaceBlur: num(40, 0, 100), surfaceDim: num(35, 0, 100), panelRadius: num(PANEL_RADIUS, 0, 200), surfaceGrain: num(0, 0, 100),
    surfaceShadow: bool(false), surfaceEdge: bool(true),
    artShape: num(1, 0, 5), artSize: num(96, 32, 400), artBorder: num(0, 0, 8), artGlow: num(0, 0, 100),
    artTilt: bool(false), artReflect: bool(false), artGreyPaused: bool(false), artSpin: bool(true), artClick: num(0, 0, 2),
    controlsShow: num(1, 0, 2), dockStyle: num(0, 0, 5), showSkip: bool(true), showShuffleRepeat: bool(false),
    progressStyle: num(1, 0, 11), timeLabels: num(1, 0, 2),
    trackTextStyle: num(0, 0, 2), trackShowAlbum: bool(false), trackScroll: bool(true),
    // card details that are part of a look
    cardAccentSource: num(0, 0, 2), artSparks: bool(false), hoverLift: bool(false),
    posterLines: num(2, 1, 3), posterVizBehind: bool(true), posterVizOpacity: num(60, 5, 100), posterClock: bool(true),
    orbitCenter: num(0, 0, 3), orbitRotate: bool(true), orbitCoverPulse: bool(true), orbitGlowRing: bool(false)
}

function defaults() {
    const o = {}
    for (const k in keys) o[k] = keys[k].def
    return o
}

// a full settings object from a partial one: unknown keys dropped, wrong types and out of range values replaced
function complete(partial) {
    const o = defaults()
    for (const k in keys) {
        const v = partial ? partial[k] : undefined
        const spec = keys[k]
        if (typeof v !== spec.type || (spec.type === "number" && (!isFinite(v) || v < spec.min || v > spec.max))
                || (spec.type === "string" && !spec.pattern.test(v)))
            continue
        o[k] = spec.type === "number" ? Math.round(v) : v
    }
    return o
}

// one line about each built-in look (shown in the settings, and in docs/gallery.md)
const about = {
    "Classic bars": "Plain bars, nothing else.",
    "Soft wave": "A smooth wave with a soft glow, in the Lagoon palette.",
    "Neon mountain": "A glowing ridge that follows the music, in orchid colors.",
    "LED rack": "A stereo-rack meter: green to red segments with caps that hang on.",
    "Dot matrix": "A grid of lit pixels, in warm Cinder colors.",
    "Orb pulse": "An orb that breathes with the bass; the lyrics swell a little on the beat.",
    "Radial rainbow": "A turning ring of spokes in a slowly moving rainbow.",
    "Green scope": "An oscilloscope trace with a green glow.",
    "Silk ribbon": "A flowing ribbon in sunset colors.",
    "Spark storm": "Sparks bounce on every beat; the edges glow with the bass.",
    "Calm": "A slow, muted wave with reduced motion: easy on the eyes.",
    "Battery friendly": "Bars at 20 frames a second, no glow, no motion effects.",
    "Neon terrain": "A skyline of peaks over a grid that rolls towards you (GPU).",
    "Tunnel run": "Rings and spokes rushing past, in rainbow colors (GPU).",
    "Plasma wash": "A warm liquid field that swells with the bass (GPU).",
    "Stereo scope": "Left against right: the stereo image as a glowing figure.",
    "Plain card": "Cover, text, buttons and a sleek seek bar on a dark card.",
    "Frosted card": "The same layout on a frosted-glass card with a soft shadow.",
    "Cover wash": "The cover blurred behind the card, a round cover with a glow.",
    "Midnight neon": "A near-black card with a neon mountain and a pulsing seek bar.",
    "Turntable": "A spinning record on an atmosphere of the cover's colors.",
    "Disc player": "A CD with a squiggle seek bar over the blurred cover.",
    "Arcade": "A sharp pixel cover, an LED meter and a time-only readout.",
    "Glass lens": "Clear glass: the cover seen through a lens that follows the pointer.",
    "Quiet glass": "A calm frosted card with a mirrored wave and one round play button.",
    "Album mist": "The cover's colors bleed in from the corners; a ribbon below.",
    "Lyrics card": "The song's lyric line under the artist, with a ribbon.",
    "Poster": "The title set big, the music as a soft texture behind it, and a clock.",
    "Hanging bars": "A centered title with bars hanging from the top edge.",
    "Stalactites": "Peak bars drip from the top edge towards the title, in icy colors.",
    "Hero stage": "The visualizer takes the stage; the track text tucks underneath.",
    "Orbit": "The cover is the center; bars circle it and the cover breathes with the bass.",
    "Halo": "A spinning record inside a ring of bars, with a progress ring.",
    "Slim strip": "A wide, low bar for the bottom of the screen.",
    "Mirrored minimal": "Cover on the right, dotted progress, no card, buttons on hover.",
    "Compact": "No cover column: visualizer, seek bar and title only."
}

const builtin = [
    // visualizer looks
    { name: "Classic bars", settings: { visualizerStyle: 0 } },
    { name: "Soft wave", settings: { visualizerStyle: 1, vizSmoothing: 60, vizColorMode: 1, vizPalette: 1, vizGlow: 20 } },
    { name: "Neon mountain", settings: { visualizerStyle: 5, vizSmoothing: 50, vizColorMode: 1, vizPalette: 4, vizGlow: 40, barGap: 6 } },
    { name: "LED rack", settings: { visualizerStyle: 4, blockHeight: 5, blockSpacing: 2, barWidth: 8, vizPeakFall: 55 } },
    { name: "Dot matrix", settings: { visualizerStyle: 7, blockHeight: 6, blockSpacing: 3, barWidth: 6, vizColorMode: 1, vizPalette: 3 } },
    { name: "Orb pulse", settings: { visualizerStyle: 11, vizSmoothing: 40, vizColorMode: 2, vizGlow: 40, lyricPulse: 20 } },
    { name: "Radial rainbow", settings: { visualizerStyle: 10, vizSmoothing: 30, vizColorMode: 2, vizRainbowSpeed: 40, barWidth: 4 } },
    { name: "Green scope", settings: { visualizerStyle: 6, vizSmoothing: 30, vizColorMode: 1, vizPalette: 2, vizGlow: 50, barWidth: 2 } },
    { name: "Silk ribbon", settings: { visualizerStyle: 12, vizSmoothing: 70, vizColorMode: 1, vizPalette: 0, vizGlow: 25, barGap: 6 } },
    { name: "Spark storm", settings: { visualizerStyle: 14, vizColorMode: 3, vizGlow: 30, barWidth: 4, lyricPulse: 15, panelGlow: 30 } },
    { name: "Calm", settings: { visualizerStyle: 1, vizSmoothing: 80, vizReleaseMs: 700, vizColorMode: 1, vizPalette: 7, reducedMotion: true } },
    { name: "Battery friendly", settings: { visualizerStyle: 0, batterySaver: true } },
    { name: "Neon terrain", settings: { showLyrics: false, visualizerStyle: 17, vizColorMode: 1, vizPalette: 4, vizSmoothing: 30 } },
    { name: "Tunnel run", settings: { showLyrics: false, visualizerStyle: 18, vizColorMode: 2, vizSmoothing: 20 } },
    { name: "Plasma wash", settings: { showLyrics: false, visualizerStyle: 15, vizColorMode: 1, vizPalette: 0, vizSmoothing: 40 } },
    { name: "Stereo scope", settings: { showLyrics: false, visualizerStyle: 19, vizColorMode: 1, vizPalette: 2, vizGlow: 40, barWidth: 2 } },
    // cards
    { name: "Plain card", settings: { layoutMode: 2, cardSurface: 1, panelColor: "#e61c2030", progressStyle: 1, visualizerStyle: 3, vizSmoothing: 40, barWidth: 4, barGap: 3 } },
    { name: "Frosted card", settings: { layoutMode: 2, cardSurface: 3, surfaceBlur: 80, artShape: 1, progressStyle: 4, dockStyle: 0, visualizerStyle: 1, vizSmoothing: 50, vizGlow: 20, surfaceShadow: true } },
    { name: "Cover wash", settings: { layoutMode: 2, cardSurface: 2, surfaceBlur: 70, surfaceDim: 45, artShape: 3, artGlow: 40, progressStyle: 3, trackTextStyle: 1 } },
    { name: "Midnight neon", settings: { layoutMode: 2, cardSurface: 6, panelColor: "#ff0b0d16", visualizerStyle: 5, vizColorMode: 1, vizPalette: 4, vizGlow: 40, vizSmoothing: 50, progressStyle: 3, dockStyle: 3, surfaceGrain: 20 } },
    { name: "Turntable", settings: { layoutMode: 2, cardSurface: 5, artShape: 4, artSize: 110, progressStyle: 6, dockStyle: 4, visualizerStyle: 14, vizColorMode: 3, artGlow: 20 } },
    { name: "Disc player", settings: { layoutMode: 2, cardSurface: 2, surfaceBlur: 60, artShape: 5, progressStyle: 6, dockStyle: 5, trackDetails: 0 } },
    { name: "Arcade", settings: { layoutMode: 2, cardSurface: 6, panelColor: "#ff07090f", artShape: 0, progressStyle: 10, dockStyle: 2, visualizerStyle: 4, blockHeight: 4, blockSpacing: 2, barWidth: 7, vizPeakFall: 60 } },
    { name: "Glass lens", settings: { layoutMode: 6, cardSurface: 4, surfaceDim: 20, artShape: 3, progressStyle: 1, dockStyle: 0, visualizerStyle: 12, vizSmoothing: 60, vizColorMode: 1, vizPalette: 5 } },
    { name: "Quiet glass", settings: { layoutMode: 6, cardSurface: 3, surfaceBlur: 85, artShape: 1, progressStyle: 2, dockStyle: 5, centeredBars: true, visualizerStyle: 1, vizSmoothing: 70 } },
    { name: "Album mist", settings: { layoutMode: 6, cardSurface: 5, artShape: 2, progressStyle: 4, dockStyle: 3, visualizerStyle: 12, vizSmoothing: 70, vizGlow: 20 } },
    { name: "Lyrics card", settings: { layoutMode: 2, cardSurface: 5, artShape: 1, progressStyle: 1, dockStyle: 4, visualizerStyle: 12, vizSmoothing: 60 } },
    { name: "Poster", settings: { layoutMode: 8, cardSurface: 0, visualizerStyle: 5, vizSmoothing: 50, vizColorMode: 1, vizPalette: 3, trackTextStyle: 1, progressStyle: 2 } },
    { name: "Hanging bars", settings: { layoutMode: 8, visualizerStyle: 3, orientation: 0, barWidth: 6, barGap: 4, vizColorMode: 1, vizPalette: 5, vizSmoothing: 40, progressStyle: 8 } },
    { name: "Stalactites", settings: { layoutMode: 8, visualizerStyle: 3, orientation: 0, barWidth: 5, barGap: 3, vizColorMode: 1, vizPalette: 5, vizPeakFall: 30, trackTextStyle: 2, progressStyle: 2 } },
    { name: "Hero stage", settings: { layoutMode: 5, visualizerStyle: 17, vizColorMode: 1, vizPalette: 1, vizSmoothing: 30, progressStyle: 1 } },
    { name: "Orbit", settings: { layoutMode: 7, artShape: 3, artGlow: 30, vizColorMode: 2, vizSmoothing: 40, progressStyle: 11, trackScroll: true } },
    { name: "Halo", settings: { layoutMode: 7, artShape: 4, vizColorMode: 1, vizPalette: 4, vizSmoothing: 50, vizGlow: 30, progressStyle: 11 } },
    { name: "Slim strip", settings: { layoutMode: 9, visualizerStyle: 0, barWidth: 3, barGap: 2, vizSmoothing: 40, progressStyle: 4, dockStyle: 4, artShape: 1 } },
    { name: "Mirrored minimal", settings: { layoutMode: 3, cardSurface: 0, progressStyle: 8, dockStyle: 4, controlsShow: 1, visualizerStyle: 1, centeredBars: true, vizSmoothing: 60 } },
    { name: "Compact", settings: { layoutMode: 10, cardSurface: 1, panelColor: "#d9141820", progressStyle: 4, visualizerStyle: 3, vizSmoothing: 40, barWidth: 3, barGap: 2 } }
].map(p => ({ name: p.name, builtin: true, about: about[p.name] || "", settings: complete(Object.assign({ showVisualizer: true, showCard: p.settings.layoutMode !== undefined }, p.settings)) }))   // a look includes its visualizer, and the card when it names a layout

// the user's presets are stored as a JSON array in one setting
function parseUser(json) {
    let a
    try { a = JSON.parse(json) } catch (e) { return [] }
    if (!Array.isArray(a)) return []
    return a.filter(p => p && typeof p.name === "string" && p.name.trim() !== "")
            .map(p => ({ name: p.name.trim().slice(0, 40), builtin: false, settings: complete(p.settings) }))
}
function serializeUser(list) {
    return JSON.stringify(list.filter(p => !p.builtin).map(p => ({ name: p.name, settings: p.settings })))
}
// favorites are kept by name; they sort first (the order inside each group is kept)
function parseFav(json) {
    try { const a = JSON.parse(json); return Array.isArray(a) ? a.filter(x => typeof x === "string") : [] } catch (e) { return [] }
}
function toggleFav(favJson, name) {
    const a = parseFav(favJson)
    const i = a.indexOf(name)
    if (i >= 0) a.splice(i, 1); else a.push(name)
    return JSON.stringify(a)
}
function all(userJson, favJson) {
    const fav = parseFav(favJson || "[]")
    const list = builtin.concat(parseUser(userJson)).map(p => Object.assign({}, p, { fav: fav.indexOf(p.name) >= 0 }))
    return list.filter(p => p.fav).concat(list.filter(p => !p.fav))
}

// add or replace a user preset of that name
function saveUser(userJson, name, settings) {
    name = (name || "").trim().slice(0, 40)
    if (name === "") return userJson
    const list = parseUser(userJson).filter(p => p.name !== name)
    list.push({ name: name, builtin: false, settings: complete(settings) })
    return serializeUser(list)
}
function deleteUser(userJson, name) {
    return serializeUser(parseUser(userJson).filter(p => p.name !== name))
}

// text form for sharing
function exportText(preset) {
    return JSON.stringify({ format: 1, name: preset.name, settings: preset.settings })
}
// {ok, preset} or {ok:false, error}
function importText(text) {
    let o
    try { o = JSON.parse(text) } catch (e) { return { ok: false, error: "That is not a preset: the text is not valid." } }
    if (!o || o.format !== 1 || typeof o.settings !== "object" || o.settings === null)
        return { ok: false, error: "That is not a preset from this widget." }
    const name = typeof o.name === "string" && o.name.trim() !== "" ? o.name.trim().slice(0, 40) : "Imported"
    return { ok: true, preset: { name: name, builtin: false, settings: complete(o.settings) } }
}

// a random built-in preset, never the same as `current` (by name) when there is a choice
function randomPick(list, current, rnd) {
    const pool = list.length > 1 ? list.filter(p => p.name !== current) : list
    return pool[Math.floor((rnd === undefined ? Math.random() : rnd) * pool.length) % pool.length]
}
// the same preset all day: chosen by the date (YYYY-MM-DD)
function dailyPick(list, dateStr) {
    let h = 0
    for (let i = 0; i < dateStr.length; ++i) h = (h * 31 + dateStr.charCodeAt(i)) >>> 0
    return list[h % list.length]
}
