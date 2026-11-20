.pragma library
// The settings of the widget, once. Every page of Settings is drawn from this by settings/SettingsPage.qml, and the
// config page files are generated from it (tools/gen-settings.js), so a setting cannot exist in one place only.
// tests/settings.test.js checks it against config/main.xml.
//
// page:    { id, title, icon, subtitle, banner?, preview?, sections }
// section: { id, title, desc, open?, rows }
// row:     { key, type, label, hint?, when?, ... }  (types below)
//   bool                         a switch
//   int     min max step off unit  a number; `off` is the text shown at the lowest value; `unit`: {div, decimals, suffix}
//   real    min max scale        a decimal stored as 0..1 (shown x scale, as a percent)
//   combo   options [values]     a list; `values` when the stored numbers do not start at 0, or are strings
//   color   alpha                a color
//   text    placeholder          a line of text
//   file    folder               a .qml file from ~/.local/share/lyric-widget/<folder>/
//   font                         a font family
//   flow                         how several colors are laid over text or bars
//   pair    keys names min max step unit   two numbers, each with its name (X / Y for places, Width / Height for sizes)
//   align   keys                 a 3 x 3 grid for the horizontal and vertical place
//   colors  spec                 a color setup (source, list, hue range...), stored as JSON; spec: bar | fill | inactive
//   palette                      one of the built-in palettes
//   eq                           the equalizer bands
//   source                       the audio capture source, with a list of what is available
//   presets                      the visualizer look manager
//   layoutedit                   the editor for the parts of a card layout (stored as JSON text)
//   spotify / browser / sites    the player-source tools on the Sources page
//   info    text                 a paragraph
// Conventions: a label is a short noun phrase in sentence case with no unit; the unit is `unit.suffix` (" px", " %", " s", " ms", " Hz"),
// shown in the box. `off` is the text at the lowest value. Positions are X / Y pairs, sizes Width / Height pairs, a place is the 3 x 3 grid.
// when: {key, in:[...]} | {key, in:"positive"} | {key, not:[...]} | a list of those (all must hold)  the row is shown only then.
//       panel: true = only in a panel.

const colorSources = ["The card's accent", "The text color", "The Plasma accent", "A color of my own"]
const flows = ["Left to right", "Bottom to top", "Right to left", "Top to bottom", "From the center", "Fill (main color only)", "To the center"]
const flowValues = [0, 1, 2, 3, 4, 5, 6]
const weights = ["Light", "Normal", "Medium", "Semi-bold", "Bold", "Black"]
const weightValues = [300, 400, 500, 600, 700, 900]

// ---- General
const general = [
    { id: "show", title: "What to show", desc: "What the widget draws.", open: true, rows: [
        { key: "showLyrics", type: "bool", label: "Lyrics" },
        { key: "showVisualizer", type: "bool", label: "Visualizer", hint: "Needs cava." },
        { key: "showCard", type: "bool", label: "Card" }
    ] },
    { id: "size", title: "Size on the desktop", desc: "On the desktop.", rows: [
        { key: "sizeMode", type: "combo", label: "Size", options: ["Free: drag the edges", "Fixed", "Full screen width"],
          hint: "Free means drag the edges." },
        { key: "widthPx", type: "int", label: "Width", unit: { suffix: " px" }, min: 0, max: 7680, step: 10, when: { key: "sizeMode", in: [1] } },
        { key: "heightPx", type: "int", label: "Height", unit: { suffix: " px" }, min: 0, max: 4000, step: 10, when: { key: "sizeMode", in: [1, 2] } }
    ] },
    { id: "hide", title: "Hide and pause", desc: "When it steps aside.", rows: [
        { key: "hideWhenNothingPlaying", type: "bool", label: "Hide when nothing is playing" },
        { key: "hideAfterSec", type: "int", label: "Hide after pause or silence", unit: { suffix: " s" }, min: 0, max: 3600, step: 10, off: "Off" },
        { key: "pauseOnFullScreenWindow", type: "bool", label: "Stop drawing while a window is full screen" },
        { key: "pauseOnMaximizedWindow", type: "bool", label: "Hide while a window is maximized" }
    ] },
    { id: "power", title: "Motion and power", desc: "Calm it or save power.", rows: [
        { key: "reducedMotion", type: "bool", label: "Reduced motion", hint: "No animation or pulses." },
        { key: "batterySaver", type: "bool", label: "Battery saver", hint: "Lower frame rate, no glow." },
        { key: "simpleRender", type: "bool", label: "Simple rendering", hint: "No glow, blur or GPU styles." },
        { key: "idleThrottle", type: "bool", label: "Redraw slowly after a long silence" },
        { key: "dimWhenPaused", type: "bool", label: "Dim the widget while paused" }
    ] }
]

// ---- Lyrics
const lyrics = [
    { id: "lines", title: "What to show", desc: "Which lines show.", open: true, rows: [
        { key: "showNeighbours", type: "bool", label: "Previous and next lines" },
        { key: "showRoman", type: "bool", label: "Romanized text", hint: "Pronunciation under the line." },
        { key: "showHeader", type: "bool", label: "Artist and title above the lines", hint: "Card off only." },
        { key: "animateLines", type: "bool", label: "Animate line changes" },
        { key: "karaoke", type: "bool", label: "Karaoke effect", hint: "Words light up as sung." },
        { key: "lyricPulse", type: "int", label: "Swell on the beat", min: 0, max: 100, off: "Off", hint: "Needs the visualizer." }
    ] },
    { id: "text", title: "Text", desc: "Font, size, weight.", rows: [
        { key: "fontFamily", type: "font", label: "Font", hint: "Empty is the system font." },
        { key: "mainSize", type: "int", label: "Current line size", min: 0, max: 300 },
        { key: "sideSize", type: "int", label: "Other lines size", min: 0, max: 300 },
        { key: "currentWeight", type: "combo", label: "Current line weight", options: weights, values: weightValues },
        { key: "sideWeight", type: "combo", label: "Other lines weight", options: weights, values: weightValues },
        { key: "fontItalic", type: "bool", label: "Italic" },
        { key: "fontUnderline", type: "bool", label: "Underline" },
        { key: "fontCaps", type: "combo", label: "Letters", options: ["As written", "UPPERCASE", "lowercase", "Small caps"] },
        { key: "letterSpacing", type: "int", label: "Letter spacing", unit: { suffix: " px" }, min: -5, max: 30 }
    ] },
    { id: "colors", title: "Colors", desc: "Line colors.", rows: [
        { key: "textColor", type: "color", label: "Current line" },
        { key: "dimColor", type: "color", alpha: true, label: "Other lines" },
        { key: "autoContrast", type: "bool", label: "Switch to dark text on a light background" },
        { key: "tintFromArt", type: "bool", label: "Use colors from the album cover", hint: "Replaces the colors above." },
        { key: "tintMode", type: "combo", label: "Cover colors", options: ["Multiple colors", "One color"], when: { key: "tintFromArt", in: [true] } },
        { key: "lyricColorFlow", type: "flow", label: "Color flow", when: { key: "tintFromArt", in: [true] } }
    ] },
    { id: "effects", title: "Effects", desc: "Shadow, outline, bar.", rows: [
        { key: "shadowOn", type: "bool", label: "Shadow" },
        { key: "shadowColor", type: "color", alpha: true, label: "Shadow color", when: { key: "shadowOn", in: [true] } },
        { type: "pair", keys: ["shadowX", "shadowY"], names: ["X", "Y"], label: "Shadow offset", unit: { suffix: " px" }, min: -30, max: 30, when: { key: "shadowOn", in: [true] } },
        { key: "shadowBlur", type: "int", label: "Shadow blur", min: 0, max: 30, when: { key: "shadowOn", in: [true] } },
        { key: "outlineOn", type: "bool", label: "Outline" },
        { key: "outlineColor", type: "color", label: "Outline color", when: { key: "outlineOn", in: [true] } },
        { key: "outlineWidth", type: "int", label: "Outline width", unit: { suffix: " px" }, min: 1, max: 6, when: { key: "outlineOn", in: [true] } },
        { key: "highlightOn", type: "bool", label: "Highlight bar behind the current line" },
        { key: "highlightColor", type: "color", alpha: true, label: "Highlight color", when: { key: "highlightOn", in: [true] } },
        { type: "pair", keys: ["highlightPadX", "highlightPadY"], names: ["Horizontal", "Vertical"], label: "Highlight padding", unit: { suffix: " px" }, min: 0, max: 100, when: { key: "highlightOn", in: [true] } },
        { key: "highlightRadius", type: "int", label: "Highlight corners", unit: { suffix: " px" }, min: 0, max: 100, when: { key: "highlightOn", in: [true] } }
    ] },
    { id: "timing", title: "Timing and buttons", desc: "Keep in step with the song.", rows: [
        { key: "offsetMs", type: "int", label: "Shift all lyrics", min: -5000, max: 5000, step: 50, unit: { div: 1000, decimals: 2, suffix: " s" },
          hint: "Positive is earlier." },
        { key: "showSyncControls", type: "bool", label: "Sync buttons on hover", hint: "Remembered per song." },
        { key: "hoverButtons", type: "bool", label: "Corner buttons on hover", hint: "Other lyrics, and the library." }
    ] },
    { id: "position", title: "Position", desc: "Where the lines sit.", rows: [
        { type: "align", keys: ["lyricsHAlign", "lyricsVAlign"], label: "Place" },
        { type: "pair", keys: ["lyricsOffsetX", "lyricsOffsetY"], names: ["X", "Y"], label: "Move", unit: { suffix: " px" }, min: -4000, max: 4000, step: 5 }
    ] }
]

// ---- Visualizer
const styles = ["Bars", "Wave", "Blocks", "Peak bars", "LED meter", "Mountain", "Oscilloscope", "Pixel matrix", "Floating dots", "Tech line",
                "Radial burst", "Pulse orb", "Ribbon", "Sparkles", "Gravity sparks", "Plasma (GPU)", "Orbit ring", "Terrain (GPU)", "Tunnel (GPU)",
                "Stereo scope", "Custom (my own QML file)", "CRT oscilloscope", "Silk ribbon"]
const styleValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
const visualizer = [
    { id: "presets", title: "Looks", desc: "Pick a look or save your own.", open: true, rows: [
        { type: "presets" }
    ] },
    { id: "style", title: "Style", desc: "What is drawn.", rows: [
        { key: "visualizerStyle", type: "combo", label: "Style", options: styles, values: styleValues },
        { key: "waveMode", type: "combo", label: "Shape", options: ["Curve", "Square", "Triangle"], when: { key: "visualizerStyle", in: [1] } },
        { key: "fillWave", type: "bool", label: "Fill the wave", when: { key: "visualizerStyle", in: [1] } },
        { key: "pinnedDownSides", type: "bool", label: "Pin down the first and last values", when: { key: "visualizerStyle", in: [1] } },
        { key: "drawInactiveBlocks", type: "bool", label: "Draw the inactive blocks", when: { key: "visualizerStyle", in: [2] } },
        { key: "roundedBars", type: "bool", label: "Rounded bars", when: { key: "visualizerStyle", in: [0] } },
        { key: "centeredBars", type: "bool", label: "Centered" },
        { key: "waveSimulateWaveform", type: "bool", label: "Simulate a waveform", when: [{ key: "visualizerStyle", in: [1] }, { key: "centeredBars", in: [true] }] },
        { key: "orientation", type: "combo", label: "Grows from", options: ["Top", "Bottom", "Left", "Right"] },
        { key: "barWidth", type: "int", label: "Bar or line width", min: 1, max: 999 },
        { key: "barGap", type: "int", label: "Gap between bars", min: 0, max: 999 },
        { key: "blockHeight", type: "int", label: "Block height", min: 1, max: 999, when: { key: "visualizerStyle", in: [2] } },
        { key: "blockSpacing", type: "int", label: "Block gap", min: 0, max: 999, when: { key: "visualizerStyle", in: [2] } },
        { key: "ribbonCurvature", type: "int", label: "Ribbon sway", unit: { suffix: " %" }, min: 0, max: 300, when: { key: "visualizerStyle", in: [12, 22] } },
        { key: "ribbonFullness", type: "int", label: "Ribbon fullness", unit: { suffix: " %" }, min: 10, max: 300, when: { key: "visualizerStyle", in: [12, 22] } },
        { key: "allowCustomQml", type: "bool", label: "Allow my own QML visualizers", hint: "Runs your file with no sandbox." },
        { key: "customQmlFile", type: "file", folder: "visualizers", label: "Custom visualizer file", when: { key: "allowCustomQml", in: [true] } }
    ] },
    { id: "circle", title: "Circle", desc: "Bend into a ring.", rows: [
        { key: "circleMode", type: "bool", label: "Circle mode" },
        { key: "circleModeSize", type: "real", label: "Circle size", min: 0, max: 99, scale: 100, when: { key: "circleMode", in: [true] } },
        { key: "circleModeFill", type: "bool", label: "Fill the circle", when: { key: "circleMode", in: [true] } }
    ] },
    { id: "colors", title: "Colors", desc: "How it is colored.", rows: [
        { key: "vizColorMode", type: "combo", label: "Color mode", options: ["The colors set below", "A palette", "Rainbow", "Rainbow pushed by the treble", "Colors from the album cover"],
          hint: "Replaces the colors below." },
        { key: "vizPalette", type: "palette", label: "Palette", when: { key: "vizColorMode", in: [1] } },
        { key: "vizRainbowSpeed", type: "int", label: "Rainbow speed", min: 0, max: 100, when: { key: "vizColorMode", in: [2, 3] } },
        { key: "barColors", type: "colors", spec: "bar", label: "Bar or wave color", when: { key: "vizColorMode", in: [0] } },
        { key: "waveFillColors", type: "colors", spec: "fill", label: "Wave fill color", when: [{ key: "visualizerStyle", in: [1] }, { key: "fillWave", in: [true] }] },
        { key: "inactiveBlockColors", type: "colors", spec: "inactive", label: "Inactive block color", when: [{ key: "visualizerStyle", in: [2] }, { key: "drawInactiveBlocks", in: [true] }] },
        { key: "vizColorFlow", type: "flow", label: "Color flow", hint: "For cover colors.", when: { key: "vizColorMode", in: [0, 4] } },
        { key: "vizColorByLevel", type: "bool", label: "Color each bar by how loud it is" },
        { key: "vizGlow", type: "int", label: "Glow", min: 0, max: 100, off: "Off" },
        { key: "vizGlowColorMode", type: "combo", label: "Glow color", options: ["Same as the bars", "The first bar color", "White"], when: { key: "vizGlow", in: "positive" } }
    ] },
    { id: "reaction", title: "Reaction to the music", desc: "How it follows the music.", rows: [
        { key: "vizSmoothing", type: "int", label: "Smoothing", min: 0, max: 100, off: "Off" },
        { key: "vizReleaseMs", type: "int", label: "Fall back after silence", unit: { suffix: " ms" }, min: 50, max: 3000, step: 50 },
        { key: "vizPeakFall", type: "int", label: "Peak caps fall speed", min: 0, max: 100 },
        { type: "pair", keys: ["vizBassWeight", "vizTrebleWeight"], names: ["Bass", "Treble"], label: "Bass and treble", unit: { suffix: " %" }, min: 0, max: 300,
          hint: "100 changes nothing." },
        { key: "vizTaper", type: "bool", label: "Soften the first and last bars" },
        { key: "vizSpacing", type: "combo", label: "Frequency axis", options: ["As cava (logarithmic)", "Mel", "Linear"] },
        { key: "fadeVizWhenPaused", type: "bool", label: "Fade while paused" }
    ] },
    { id: "panel", title: "Size in a panel", desc: "In a panel only.", rows: [
        { key: "expanding", type: "bool", label: "Fill the panel's length", panel: true },
        { key: "length", type: "int", label: "Fixed length", unit: { suffix: " px" }, min: 1, max: 9999, when: { key: "expanding", in: [false] }, panel: true },
        { key: "minimumLength", type: "int", label: "Minimum length", unit: { suffix: " px" }, min: 1, max: 9999, when: { key: "expanding", in: [true] }, panel: true },
        { key: "fillPanel", type: "bool", label: "Fill the panel's thickness", panel: true }
    ] },
    { id: "position", title: "Position", desc: "Where it sits.", rows: [
        { type: "pair", keys: ["vizWidthPct", "vizHeightPct"], names: ["Width", "Height"], label: "Size", unit: { suffix: " %" }, min: 0, max: 100 },
        { type: "align", keys: ["vizHAlign", "vizVAlign"], label: "Place" },
        { type: "pair", keys: ["vizOffsetX", "vizOffsetY"], names: ["X", "Y"], label: "Move", unit: { suffix: " px" }, min: -4000, max: 4000, step: 5 }
    ] }
]

// ---- Audio input (the capture is done by cava)
const audio = [
    { id: "input", title: "Where the sound comes from", desc: "Change only if the bars stay flat.", open: true, rows: [
        { key: "inputMethod", type: "combo", label: "Method", values: ["", "oss", "pipewire", "sndio", "jack", "pulse", "alsa", "portaudio", "fifo", "shmem"],
          options: ["Default", "OSS", "PipeWire", "Sndio", "JACK", "PulseAudio", "ALSA", "PortAudio", "FIFO", "shmem"],
          hint: "Default picks for you." },
        { key: "inputSource", type: "source", label: "Source", hint: "Empty hears everything you play." },
        { key: "sampleRate", type: "int", label: "Sample rate", unit: { suffix: " Hz" }, min: 1, max: 192000, step: 1000 },
        { key: "sampleBits", type: "int", label: "Sample bits", min: 8, max: 32, step: 8, hint: "Some methods only." },
        { key: "inputChannels", type: "int", label: "Channels", min: 2, max: 4 },
        { key: "autoconnect", type: "int", label: "Auto connect", min: 2, max: 4, hint: "Jack only." },
        { key: "active", type: "bool", label: "Keep the capture active", hint: "PipeWire only." },
        { key: "remix", type: "bool", label: "Remix channels", hint: "PipeWire only." },
        { key: "virtual", type: "bool", label: "Virtual node", hint: "PipeWire only." }
    ] },
    { id: "output", title: "What is drawn", desc: "How sound becomes bars.", rows: [
        { key: "framerate", type: "int", label: "Frame rate", min: 1, max: 144 },
        { key: "barCount", type: "int", label: "Number of bars", min: 1, max: 512, hint: "Set automatically." },
        { key: "outputChannels", type: "combo", label: "Channels shown", values: ["mono", "stereo"], options: ["Mono", "Stereo"] },
        { key: "monoOption", type: "combo", label: "Which channel", values: ["left", "right", "average"], options: ["Left", "Right", "Average"], when: { key: "outputChannels", in: ["mono"] } },
        { key: "reverse", type: "bool", label: "Reverse the frequencies" },
        { key: "waveform", type: "bool", label: "Waveform instead of spectrum" }
    ] },
    { id: "level", title: "Level and range", desc: "Loudness and pitch range.", rows: [
        { key: "autoSensitivity", type: "int", label: "Automatic sensitivity", min: 0, max: 10, off: "Off", hint: "1 is normal." },
        { key: "sensitivityEnabled", type: "bool", label: "Set the sensitivity myself" },
        { key: "sensitivity", type: "int", label: "Sensitivity", unit: { suffix: " %" }, min: 1, max: 999, when: { key: "sensitivityEnabled", in: [true] } },
        { type: "pair", keys: ["lowerCutoffFreq", "higherCutoffFreq"], names: ["From", "To"], label: "Pitch range", unit: { suffix: " Hz" }, min: 1, max: 22000, step: 100 },
        { key: "noiseReduction", type: "int", label: "Noise reduction", min: 0, max: 100, hint: "Higher is smoother." },
        { key: "monstercat", type: "bool", label: "Monstercat smoothing" },
        { key: "waves", type: "bool", label: "Waves", when: { key: "monstercat", in: [true] } }
    ] },
    { id: "eq", title: "Equalizer", desc: "Boost or cut pitches.", rows: [
        { key: "eqEnabled", type: "bool", label: "Use the equalizer" },
        { key: "eq", type: "eq", label: "Bands", when: { key: "eqEnabled", in: [true] } }
    ] }
]

// ---- Card
const cardSections = [
    { id: "layout", title: "Layout", desc: "How the card is arranged.", open: true, rows: [
        { key: "layoutMode", type: "combo", label: "Layout", options: ["Classic", "Mirrored", "Inline", "Hero wave", "Stacked", "Orbit", "Poster", "Slim strip", "Compact (no art)", "Icon (cover in a progress ring)"], values: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11], hint: "The card is turned on in General." },
        { key: "cardAccentSource", type: "combo", label: "Accent color", options: ["Same as the lyrics", "The Plasma accent", "A color of my own"] },
        { key: "customAccent", type: "color", label: "My accent", when: { key: "cardAccentSource", in: [2] } }
    ] },
    { id: "edit", title: "Edit the layout", desc: "Hide, move, resize, fade.", rows: [
        { key: "layoutEdits", type: "layoutedit", label: "" }
    ] },
    { id: "surface", title: "Background and glow", desc: "Corners and glow.", rows: [
        { key: "cardSurface", type: "combo", label: "Background", options: ["None", "Color", "Art backdrop", "Glass", "Liquid glass", "Atmosphere", "Solid"] },
        { key: "panelColor", type: "color", alpha: true, label: "Color", when: { key: "cardSurface", in: [1, 6] } },
        { key: "glassTint", type: "combo", label: "Glass tint", options: ["Clear", "Dark", "Light", "The accent"], when: { key: "cardSurface", in: [3] } },
        { key: "surfaceBlur", type: "int", label: "Blur", min: 0, max: 100, when: { key: "cardSurface", in: [2, 3] } },
        { key: "surfaceDim", type: "int", label: "Darken", min: 0, max: 100, when: { key: "cardSurface", in: [2, 3, 4] } },
        { key: "compositorGlass", type: "bool", label: "Blur the desktop behind", when: { key: "cardSurface", in: [3, 4] }, hint: "Needs KWin's Blur effect." },
        { key: "panelRadius", type: "int", label: "Corner radius", min: 0, max: 200, when: { key: "cardSurface", in: [1, 2, 3, 4, 5, 6] } },
        { key: "surfaceGrain", type: "int", label: "Film grain", min: 0, max: 100, when: { key: "cardSurface", in: [1, 2, 3, 4, 5, 6] }, off: "Off" },
        { key: "surfaceShadow", type: "bool", label: "Shade the bottom edge", when: { key: "cardSurface", in: [1, 2, 3, 4, 5, 6] } },
        { key: "surfaceEdge", type: "bool", label: "Light edge", when: { key: "cardSurface", in: [1, 2, 3, 4, 5, 6] } },
        { key: "panelGlow", type: "int", label: "Edge glow with the bass", min: 0, max: 100, hint: "Needs the visualizer.", off: "Off" },
        { key: "ambientGlow", type: "int", label: "Glow around the card", min: 0, max: 100, hint: "Needs the visualizer.", off: "Off" }
    ] },
    { id: "cover", title: "Cover", desc: "The album picture.", rows: [
        { key: "artShape", type: "combo", label: "Shape", options: ["Sharp", "Rounded", "Squircle", "Circle", "Vinyl record", "CD"] },
        { key: "artFormat", type: "combo", label: "Format", options: ["Square", "Wide (4:3)"], when: { key: "artShape", in: [0, 1, 2] } },
        { key: "artSize", type: "int", label: "Size", unit: { suffix: " px" }, min: 32, max: 400 },
        { key: "artFit", type: "combo", label: "Picture in the shape", options: ["Fill the shape (crop the picture)", "The whole picture (empty bars)"] },
        { type: "align", keys: ["artFocusH", "artFocusV"], label: "Part of the picture to keep", when: { key: "artFit", in: [0] } },
        { key: "artBorder", type: "int", label: "Border", unit: { suffix: " px" }, min: 0, max: 8, off: "None" },
        { key: "artGlow", type: "int", label: "Glow", min: 0, max: 100, off: "Off" },
        { key: "artTilt", type: "bool", label: "Tilt it" },
        { key: "artReflect", type: "bool", label: "Reflection" },
        { key: "artGreyPaused", type: "bool", label: "Gray while paused" },
        { key: "artSpin", type: "bool", label: "Records and CDs turn while playing", when: { key: "artShape", in: [4, 5] } },
        { key: "artSparks", type: "bool", label: "Sparks on every beat" },
        { key: "artThumbnail", type: "combo", label: "YouTube videos", options: ["The player's cover", "The video's own picture"] },
        { key: "artFallback", type: "combo", label: "With no picture", options: ["A music note", "The first letter of the title", "Color only"] },
        { key: "artClick", type: "combo", label: "Click on the cover", options: ["Nothing", "Play / pause", "Show the details"] }
    ] },
    { id: "buttons", title: "Buttons", desc: "Previous, play, next.", rows: [
        { key: "controlsShow", type: "combo", label: "Show", options: ["Never", "When the pointer is over the card", "Always"] },
        { key: "dockStyle", type: "combo", label: "Look", options: ["Glass", "Soft", "Outline", "Tinted", "Bare", "Accent play button", "My own QML file"], when: { key: "controlsShow", in: [1, 2] } },
        { key: "customButtonsFile", type: "file", folder: "buttons", label: "Buttons file", when: { key: "dockStyle", in: [6] } },
        { key: "controlsColorSource", type: "combo", label: "Color", options: ["The card's accent", "The text color", "The Plasma accent", "A color of my own"], when: { key: "controlsShow", in: [1, 2] } },
        { key: "customControlColor", type: "color", label: "My button color", when: { key: "controlsColorSource", in: [3] } },
        { key: "showSkip", type: "bool", label: "Previous and next", when: { key: "controlsShow", in: [1, 2] } },
        { key: "showShuffleRepeat", type: "bool", label: "Shuffle and repeat", when: { key: "controlsShow", in: [1, 2] } }
    ] },
    { id: "seek", title: "Seek bar", desc: "Song progress.", rows: [
        { key: "progressStyle", type: "combo", label: "Style", options: ["None", "Sleek", "Minimal", "Glow pulse", "Pill", "Waveform", "Squiggle", "Segmented", "Dotted", "Capsule", "Time only", "Ring round the cover", "My own QML file"] },
        { key: "customProgressFile", type: "file", folder: "progress", label: "Seek bar file", when: { key: "progressStyle", in: [12] } },
        { key: "progressColorSource", type: "combo", label: "Color", options: ["The card's accent", "The text color", "The Plasma accent", "A color of my own"] },
        { key: "customProgressColor", type: "color", label: "My seek bar color", when: { key: "progressColorSource", in: [3] } },
        { key: "timeLabels", type: "combo", label: "Times", options: ["Off", "Elapsed and total", "Elapsed and remaining"] },
        { key: "seekHover", type: "bool", label: "Show the time under the pointer" },
        { key: "showChapters", type: "bool", label: "Chapter marks" },
        { key: "reactiveProgress", type: "bool", label: "Pulse with the beat" },
        { key: "wheelSeekSec", type: "int", label: "Mouse wheel on the bar", unit: { suffix: " s" }, min: 0, max: 60, off: "Off" },
        { key: "doubleClickSkip", type: "bool", label: "Double click skips 10 s" }
    ] },
    { id: "text", title: "Title and details", desc: "Name and details.", rows: [
        { key: "trackTextStyle", type: "combo", label: "Look", options: ["Plain", "Shadow", "Frosted plate"] },
        { key: "titleSize", type: "int", label: "Title size", unit: { suffix: " px" }, min: 9, max: 48 },
        { key: "textAlign", type: "combo", label: "Alignment", options: ["By the layout", "Left", "Center", "Right"] },
        { key: "trackShowAlbum", type: "bool", label: "Show the album" },
        { key: "showSource", type: "bool", label: "Show which player it is" },
        { key: "showPlayerSwitch", type: "bool", label: "Player switch button" },
        { key: "trackScroll", type: "bool", label: "Scroll long titles" },
        { key: "trackDetails", type: "combo", label: "Details", options: ["Off", "Tooltip", "Drawer under the text", "Flip the cover"] },
        { key: "onlineInfo", type: "bool", label: "Look up the song online", when: { key: "trackDetails", in: [1, 2, 3] }, hint: "Sends song names to MusicBrainz and Wikipedia." },
        { key: "detailYear", type: "bool", label: "Show: Year", when: { key: "onlineInfo", in: "positive" } },
        { key: "detailLabel", type: "bool", label: "Show: Record label", when: { key: "onlineInfo", in: "positive" } },
        { key: "detailCountry", type: "bool", label: "Show: Country", when: { key: "onlineInfo", in: "positive" } },
        { key: "detailTags", type: "bool", label: "Show: Tags", when: { key: "onlineInfo", in: "positive" } },
        { key: "detailAbout", type: "bool", label: "Show: Text about the artist", when: { key: "onlineInfo", in: "positive" } }
    ] },
    { id: "poster", title: "Poster arrangement", desc: "Poster layout only.", rows: [
        { key: "posterLines", type: "int", label: "Title lines", min: 1, max: 3, when: { key: "layoutMode", in: [8] } },
        { key: "posterVizBehind", type: "bool", label: "Music behind the title", when: { key: "layoutMode", in: [8] } },
        { key: "posterVizOpacity", type: "int", label: "Music strength", unit: { suffix: " %" }, min: 5, max: 100, when: { key: "layoutMode", in: [8] } },
        { key: "posterClock", type: "bool", label: "Show the time of day", when: { key: "layoutMode", in: [8] } }
    ] },
    { id: "orbit", title: "Orbit arrangement", desc: "Orbit layout only.", rows: [
        { key: "orbitCenter", type: "combo", label: "In the middle", options: ["The cover", "The cover and the title", "The title", "Nothing"], when: { key: "layoutMode", in: [7] } },
        { key: "orbitRotate", type: "bool", label: "The ring turns slowly", when: { key: "layoutMode", in: [7] } },
        { key: "orbitCoverPulse", type: "bool", label: "The cover breathes with the bass", when: { key: "layoutMode", in: [7] } },
        { key: "orbitGlowRing", type: "bool", label: "A glowing ring", when: { key: "layoutMode", in: [7] } }
    ] },
    { id: "behavior", title: "Pointer", desc: "Mouse over the card.", rows: [
        { key: "scrollVolume", type: "bool", label: "Scroll changes the volume" },
        { key: "hoverLift", type: "bool", label: "Lift on hover" }
    ] },
    { id: "panel", title: "In a panel", desc: "In a panel only.", rows: [
        { key: "panelMode", type: "combo", label: "In a panel", options: ["The card", "A small pill that opens the card", "The card when there is room, else the pill"] },
        { key: "panelOrientation", type: "combo", label: "Turn the card", options: ["By itself in a vertical panel", "Never", "Left", "Right"], when: { key: "panelMode", in: [0, 2] } },
        { key: "panelCardSizing", type: "combo", label: "Size of the card", options: ["Fit the panel's thickness", "A fixed scale"], when: { key: "panelMode", in: [0, 2] } },
        { key: "panelCardScale", type: "int", label: "Scale", unit: { suffix: " %" }, min: 50, max: 400, when: { key: "panelMode", in: [0, 2] } },
        { key: "pillContent", type: "combo", label: "Pill text", options: ["Title and artist", "Title", "Artist", "Nothing"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillArt", type: "bool", label: "Cover in the pill", when: { key: "panelMode", in: [1, 2] } },
        { key: "pillEq", type: "combo", label: "Small visualizer", options: ["None", "Moving bars", "Live (uses cava)"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillProgress", type: "combo", label: "Progress", options: ["None", "A line under the text", "A ring round the cover"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillControls", type: "combo", label: "Buttons", options: ["None", "Play / pause", "Previous, play / pause, next"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillControlsOnHover", type: "bool", label: "Show the buttons only on hover", when: { key: "panelMode", in: [1, 2] } },
        { key: "pillMaxWidth", type: "int", label: "Longest the pill gets", unit: { suffix: " px" }, min: 80, max: 800, when: { key: "panelMode", in: [1, 2] } },
        { key: "pillScroll", type: "bool", label: "Scroll a long title", when: { key: "panelMode", in: [1, 2] } },
        { key: "pillPopupTrigger", type: "combo", label: "Open the card by", options: ["Clicking", "Hovering", "Clicking or hovering"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillClick", type: "combo", label: "Clicking the pill", options: ["Opens the card", "Plays or pauses", "Skips to the next song"], when: { key: "panelMode", in: [1, 2] }, hint: "Middle click plays or pauses." }
    ] },
    { id: "pill", title: "Pill look", desc: "Pill only.", rows: [
        { key: "pillArtShape", type: "combo", label: "Cover shape", options: ["Sharp", "Rounded", "Squircle", "Circle", "Vinyl record", "CD"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillArtBorder", type: "int", label: "Cover border", unit: { suffix: " px" }, min: 0, max: 8, when: { key: "panelMode", in: [1, 2] }, off: "None" },
        { key: "pillArtGlow", type: "int", label: "Cover glow", min: 0, max: 100, when: { key: "panelMode", in: [1, 2] }, off: "Off" },
        { key: "pillTextStyle", type: "combo", label: "Text", options: ["Plain", "Shadow"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillDockStyle", type: "combo", label: "Button look", options: ["Glass", "Soft", "Outline", "Tinted", "Bare", "Accent play button"], when: { key: "panelMode", in: [1, 2] } },
        { key: "pillEqStyle", type: "combo", label: "Live visualizer", options: ["Bars", "Wave"], when: { key: "pillEq", in: [2] } }
    ] }
]

// ---- Sources
const sources = [
    { id: "local", title: "Your own files", desc: "Lyrics beside your music.", open: true, rows: [
        { key: "localLyrics", type: "bool", label: "Use lyrics saved beside the song", hint: "A .lrc file, or tags in the file." },
        { key: "localLyricsFolder", type: "text", label: "Also look in this folder", placeholder: "Empty: only beside the song", when: { key: "localLyrics", in: [true] } }
    ] },
    { id: "next", title: "Next songs", desc: "Prepare ahead.", rows: [
        { key: "prefetchCount", type: "int", label: "Prepare lyrics for the next", min: 0, max: 5, off: "Off", unit: { suffix: " songs" }, hint: "Needs a queue source." },
        { type: "queuecheck", label: "Check" }
    ] },
    { id: "spotify", title: "Spotify", desc: "Lyrics and queue from the app.", rows: [
        { key: "spotifyAppQueue", type: "bool", label: "Use the Spotify app", hint: "Needs Spicetify and a debug port." },
        { key: "spotifyDebugPort", type: "int", label: "Port", min: 1024, max: 65535, when: { key: "spotifyAppQueue", in: [true] } },
        { type: "spotify", label: "Check", when: { key: "spotifyAppQueue", in: [true] } }
    ] },
    { id: "browser", title: "YouTube Music and browsers", desc: "Queue from YouTube Music.", rows: [
        { key: "browserQueue", type: "bool", label: "Get the queue from YouTube Music" },
        { key: "browserQueuePort", type: "int", label: "Port", min: 1024, max: 65535, when: { key: "browserQueue", in: [true] } },
        { type: "browser", label: "Browser extension" }
    ] },
    { id: "players", title: "Players", desc: "Which players it follows.", rows: [
        { key: "anyPlayer", type: "bool", label: "Follow any media player", hint: "Also VLC, mpv and others." },
        { key: "allowedSites", type: "sites", label: "Websites a browser may play music from" }
    ] }
]

const pages = [
    { id: "general", title: "General", icon: "configure", subtitle: "What shows, its size, when it rests.", sections: general },
    { id: "lyrics", title: "Lyrics", icon: "format-text-bold", subtitle: "The lines of the song.", preview: "lyrics", sections: lyrics },
    { id: "visualizer", title: "Visualizer", icon: "audio-input-microphone", subtitle: "Bars and waves for the music.",
      banner: { key: "showVisualizer", text: "The visualizer is off.", button: "Turn it on" }, preview: "viz", sections: visualizer },
    { id: "audio", title: "Audio input", icon: "audio-input-line", subtitle: "Where the sound comes from.",
      banner: { key: "showVisualizer", text: "The visualizer is off.", button: "Turn it on" }, sections: audio },
    { id: "card", title: "Card", icon: "view-media-playlist", subtitle: "Cover, title, buttons, seek bar.",
      banner: { key: "showCard", text: "The card is off.", button: "Turn it on" }, preview: "card", sections: cardSections },
    { id: "sources", title: "Sources", icon: "folder-music", subtitle: "Where lyrics come from.", sections: sources }
]

// ---- helpers (also used by the generator and the tests)
function rowKeys(r) { return r.keys ? r.keys : (r.key ? [r.key] : []) }
function pageKeys(p) {
    const out = []
    for (const s of p.sections) for (const r of s.rows) for (const k of rowKeys(r)) out.push(k)
    // the preset manager keeps the user's looks and favorites
    if (p.id === "visualizer") out.push("vizUserPresets", "vizFavourites")
    return out
}
function pageById(id) { return pages.find(p => p.id === id) }
// is a row's `when` met? `get(key)` reads a setting
function whenMet(when, get) {
    if (!when) return true
    // a list: all of them. (Inside QML a list arrives as an array-like object, so test for the absence of `key`, not Array.isArray.)
    if (when.key === undefined) {
        for (let i = 0; i < when.length; ++i) if (!whenMet(when[i], get)) return false
        return true
    }
    const v = get(when.key)
    if (when.not) return when.not.indexOf(v) < 0
    if (when.in === "positive") return v > 0
    return when.in.indexOf(v) >= 0
}
