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
//   pair    keys min max step    two numbers side by side
//   align   keys                 a 3 x 3 grid for the horizontal and vertical place
//   colors  spec                 a color setup (source, list, hue range...), stored as JSON; spec: bar | fill | inactive
//   palette                      one of the built-in palettes
//   eq                           the equalizer bands
//   source                       the audio capture source, with a list of what is available
//   presets                      the visualizer look manager
//   spotify / browser / sites    the player-source tools on the Sources page
//   info    text                 a paragraph
// when: {key, in:[...]} | {key, in:"positive"} | {key, not:[...]} | a list of those (all must hold)  the row is shown only then.
//       panel: true = only in a panel.

const colorSources = ["The card's accent", "The text color", "The Plasma accent", "A color of my own"]
const flows = ["Left to right", "Bottom to top", "Right to left", "Top to bottom", "From the center", "Fill (main color only)", "To the center"]
const flowValues = [0, 1, 2, 3, 4, 5, 6]
const weights = ["Light", "Normal", "Medium", "Semi-bold", "Bold", "Black"]
const weightValues = [300, 400, 500, 600, 700, 900]

// ---- General
const general = [
    { id: "show", title: "What to show", desc: "The three parts of the widget. Each has its own page on the left.", open: true, rows: [
        { key: "showLyrics", type: "bool", label: "Lyrics", hint: "The lines of the song that is playing." },
        { key: "showVisualizer", type: "bool", label: "Visualizer", hint: "Moving bars or waves that follow the music. Needs cava, a small audio capture tool." },
        { key: "showCard", type: "bool", label: "Card", hint: "The cover, title, buttons and seek bar around the lyrics. Arrange and style it on the Card page." }
    ] },
    { id: "size", title: "Size on the desktop", desc: "How big the widget is when it sits on the desktop. Press Apply to use new numbers.", rows: [
        { key: "sizeMode", type: "combo", label: "Size", options: ["Free: drag the edges", "Fixed", "Full screen width"],
          hint: "Free: you drag the widget's edges (right-click it, Enter Edit Mode). Fixed: exactly the numbers below. Full screen width: as wide as the screen, with the height below." },
        { key: "widthPx", type: "int", label: "Width (px)", min: 0, max: 7680, step: 10, when: { key: "sizeMode", in: [1] } },
        { key: "heightPx", type: "int", label: "Height (px)", min: 0, max: 4000, step: 10, when: { key: "sizeMode", in: [1, 2] },
          hint: "0 would make the widget 1 px high." }
    ] },
    { id: "hide", title: "Hide and pause", desc: "When the widget gets out of the way.", rows: [
        { key: "hideWhenNothingPlaying", type: "bool", label: "Hide when nothing is playing" },
        { key: "hideAfterSec", type: "int", label: "Hide after pause or silence (s)", min: 0, max: 3600, step: 10, off: "Off" },
        { key: "pauseOnFullScreenWindow", type: "bool", label: "Stop drawing while a window is full screen", hint: "Saves power while you watch or play something." },
        { key: "pauseOnMaximizedWindow", type: "bool", label: "Hide while a window is maximized" }
    ] },
    { id: "power", title: "Motion and power", desc: "Calm the widget or make it cheaper to run. They apply to the lyrics, the card and the visualizer.", rows: [
        { key: "reducedMotion", type: "bool", label: "Reduced motion", hint: "No line animation, particles, turning rings, drifting traces, rainbow or pulses. The bars still follow the music." },
        { key: "batterySaver", type: "bool", label: "Battery saver", hint: "The visualizer runs at 20 frames a second with no glow, and the motion effects are off." },
        { key: "simpleRender", type: "bool", label: "Simple rendering", hint: "No GPU styles, glow or blur. Turn it on if the widget is slow or the screen shows artifacts." },
        { key: "idleThrottle", type: "bool", label: "Redraw slowly after a long silence" },
        { key: "dimWhenPaused", type: "bool", label: "Dim the widget while paused" }
    ] }
]

// ---- Lyrics
const lyrics = [
    { id: "lines", title: "What to show", desc: "Which lines appear, and how they behave.", open: true, rows: [
        { key: "showNeighbours", type: "bool", label: "Previous and next lines" },
        { key: "showRoman", type: "bool", label: "Romanized text", hint: "Japanese, Korean and Chinese lines with their pronunciation." },
        { key: "showHeader", type: "bool", label: "Artist and title above the lines", hint: "Only when the card is off." },
        { key: "animateLines", type: "bool", label: "Animate line changes" },
        { key: "karaoke", type: "bool", label: "Karaoke effect", hint: "The words of the current line light up one by one as they are sung. Word times come from NetEase, QQ Music and Kugou when they have them (fetched only while this is on), and from the Word timing section of the lyrics library, which wins. Without them the words are spread over the line, so it is only a guess. Japanese and Chinese light up one character at a time." },
        { key: "lyricPulse", type: "int", label: "Swell on the beat", min: 0, max: 100, off: "Off", hint: "The text swells a little with each beat. Keep it low: a strong pulse makes the words harder to read. Needs the visualizer to be on." }
    ] },
    { id: "text", title: "Text", desc: "The font, sizes and weights.", rows: [
        { key: "fontFamily", type: "font", label: "Font", hint: "Empty uses the system font." },
        { key: "mainSize", type: "int", label: "Current line size", min: 0, max: 300 },
        { key: "sideSize", type: "int", label: "Other lines size", min: 0, max: 300 },
        { key: "currentWeight", type: "combo", label: "Current line weight", options: weights, values: weightValues },
        { key: "sideWeight", type: "combo", label: "Other lines weight", options: weights, values: weightValues },
        { key: "fontItalic", type: "bool", label: "Italic" },
        { key: "fontUnderline", type: "bool", label: "Underline" },
        { key: "fontCaps", type: "combo", label: "Letters", options: ["As written", "UPPERCASE", "lowercase", "Small caps"] },
        { key: "letterSpacing", type: "int", label: "Letter spacing (px)", min: -5, max: 30 }
    ] },
    { id: "colors", title: "Colors", desc: "The color of the lines. With the card on, its accent can follow these.", rows: [
        { key: "textColor", type: "color", label: "Current line" },
        { key: "dimColor", type: "color", alpha: true, label: "Other lines" },
        { key: "autoContrast", type: "bool", label: "Switch to dark text on a light background" },
        { key: "tintFromArt", type: "bool", label: "Use colors from the album cover", hint: "The cover's colors replace the colors above, and the visualizer's bar colors." },
        { key: "tintMode", type: "combo", label: "Cover colors", options: ["Multiple colors", "One color"], when: { key: "tintFromArt", in: [true] } },
        { key: "lyricColorFlow", type: "flow", label: "Color flow", when: { key: "tintFromArt", in: [true] } }
    ] },
    { id: "effects", title: "Effects", desc: "A shadow, an outline, or a bar behind the current line.", rows: [
        { key: "shadowOn", type: "bool", label: "Shadow" },
        { key: "shadowColor", type: "color", alpha: true, label: "Shadow color", when: { key: "shadowOn", in: [true] } },
        { type: "pair", keys: ["shadowX", "shadowY"], label: "Shadow offset (px)", min: -30, max: 30, when: { key: "shadowOn", in: [true] } },
        { key: "shadowBlur", type: "int", label: "Shadow blur", min: 0, max: 30, when: { key: "shadowOn", in: [true] } },
        { key: "outlineOn", type: "bool", label: "Outline" },
        { key: "outlineColor", type: "color", label: "Outline color", when: { key: "outlineOn", in: [true] } },
        { key: "outlineWidth", type: "int", label: "Outline width (px)", min: 1, max: 6, when: { key: "outlineOn", in: [true] } },
        { key: "highlightOn", type: "bool", label: "Highlight bar behind the current line" },
        { key: "highlightColor", type: "color", alpha: true, label: "Highlight color", when: { key: "highlightOn", in: [true] } },
        { type: "pair", keys: ["highlightPadX", "highlightPadY"], label: "Highlight padding (px)", min: 0, max: 100, when: { key: "highlightOn", in: [true] } },
        { key: "highlightRadius", type: "int", label: "Highlight corners (px)", min: 0, max: 100, when: { key: "highlightOn", in: [true] } }
    ] },
    { id: "timing", title: "Timing and buttons", desc: "Keep the words in step with the singing.", rows: [
        { key: "offsetMs", type: "int", label: "Shift all lyrics (s)", min: -5000, max: 5000, step: 50, unit: { div: 1000, decimals: 2, suffix: " s" },
          hint: "Positive: the lyrics appear earlier. Negative: later." },
        { key: "showSyncControls", type: "bool", label: "Show sync buttons when the pointer is over the widget", hint: "Nudge this one song's timing; it is remembered for the song." },
        { key: "hoverButtons", type: "bool", label: "Show the corner buttons when the pointer is over the widget", hint: "The arrows look for other lyrics for the song and keep the one they find in your library. The pencil opens the lyrics library." }
    ] },
    { id: "position", title: "Position", desc: "Where the lines sit. With the card on, the card's layout gives them a space and only the place (left, center, right, top, bottom) applies, not the offset.", rows: [
        { type: "align", keys: ["lyricsHAlign", "lyricsVAlign"], label: "Place" },
        { type: "pair", keys: ["lyricsOffsetX", "lyricsOffsetY"], label: "Move right / down (px)", min: -4000, max: 4000, step: 5 }
    ] }
]

// ---- Visualizer
const styles = ["Bars", "Wave", "Blocks", "Peak bars", "LED meter", "Mountain", "Oscilloscope", "Pixel matrix", "Floating dots", "Tech line",
                "Radial burst", "Pulse orb", "Ribbon", "Sparkles", "Gravity sparks", "Plasma (GPU)", "Orbit ring", "Terrain (GPU)", "Tunnel (GPU)",
                "Stereo scope", "Custom (my own QML file)", "CRT oscilloscope", "Silk ribbon"]
const styleValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
const visualizer = [
    { id: "presets", title: "Looks", desc: "Start here: pick a ready-made look, or save your own.", open: true, rows: [
        { type: "presets" }
    ] },
    { id: "style", title: "Style", desc: "What the music is drawn as.", rows: [
        { key: "visualizerStyle", type: "combo", label: "Style", options: styles, values: styleValues },
        { key: "waveMode", type: "combo", label: "Shape", options: ["Curve", "Square", "Triangle"], when: { key: "visualizerStyle", in: [1] } },
        { key: "fillWave", type: "bool", label: "Fill the wave", when: { key: "visualizerStyle", in: [1] } },
        { key: "pinnedDownSides", type: "bool", label: "Pin down the first and last values", when: { key: "visualizerStyle", in: [1] } },
        { key: "drawInactiveBlocks", type: "bool", label: "Draw the inactive blocks", when: { key: "visualizerStyle", in: [2] } },
        { key: "roundedBars", type: "bool", label: "Rounded bars", when: { key: "visualizerStyle", in: [0] } },
        { key: "centeredBars", type: "bool", label: "Centered", hint: "Grow from the middle. Ignored when the cava waveform option is on." },
        { key: "waveSimulateWaveform", type: "bool", label: "Simulate a waveform", hint: "Alternates the values up and down. Needs Centered, and the Wave style.", when: [{ key: "visualizerStyle", in: [1] }, { key: "centeredBars", in: [true] }] },
        { key: "orientation", type: "combo", label: "Grows from", options: ["Top", "Bottom", "Left", "Right"] },
        { key: "barWidth", type: "int", label: "Bar or line width", min: 1, max: 999 },
        { key: "barGap", type: "int", label: "Gap between bars", min: 0, max: 999 },
        { key: "blockHeight", type: "int", label: "Block height", min: 1, max: 999, when: { key: "visualizerStyle", in: [2] } },
        { key: "blockSpacing", type: "int", label: "Block gap", min: 0, max: 999, when: { key: "visualizerStyle", in: [2] } },
        { key: "ribbonCurvature", type: "int", label: "Ribbon sway (%)", min: 0, max: 300, when: { key: "visualizerStyle", in: [12, 22] } },
        { key: "ribbonFullness", type: "int", label: "Ribbon fullness (%)", min: 10, max: 300, when: { key: "visualizerStyle", in: [12, 22] } },
        { key: "allowCustomQml", type: "bool", label: "Allow my own QML visualizers", hint: "Lets the Custom style load a .qml file from ~/.local/share/lyric-widget/visualizers/. The file runs as it is, with no sandbox: only use files you trust." },
        { key: "customQmlFile", type: "file", folder: "visualizers", label: "Custom visualizer file", when: { key: "allowCustomQml", in: [true] } }
    ] },
    { id: "circle", title: "Circle", desc: "Bend the bars or the wave into a ring.", rows: [
        { key: "circleMode", type: "bool", label: "Circle mode" },
        { key: "circleModeSize", type: "real", label: "Circle size (%)", min: 0, max: 99, scale: 100, when: { key: "circleMode", in: [true] } },
        { key: "circleModeFill", type: "bool", label: "Fill the circle", when: { key: "circleMode", in: [true] } }
    ] },
    { id: "colors", title: "Colors", desc: "How the visualizer is colored. Colors from the album cover (Lyrics page) replace the ones set here.", rows: [
        { key: "vizColorMode", type: "combo", label: "Color mode", options: ["The colors set below", "A palette", "Rainbow", "Rainbow pushed by the treble"],
          hint: "A color mode other than the first replaces the colors below and the album cover colors, for the visualizer." },
        { key: "vizPalette", type: "palette", label: "Palette", when: { key: "vizColorMode", in: [1] } },
        { key: "vizRainbowSpeed", type: "int", label: "Rainbow speed", min: 0, max: 100, when: { key: "vizColorMode", in: [2, 3] } },
        { key: "barColors", type: "colors", spec: "bar", label: "Bar or wave color", when: { key: "vizColorMode", in: [0] } },
        { key: "waveFillColors", type: "colors", spec: "fill", label: "Wave fill color", when: [{ key: "visualizerStyle", in: [1] }, { key: "fillWave", in: [true] }] },
        { key: "inactiveBlockColors", type: "colors", spec: "inactive", label: "Inactive block color", when: [{ key: "visualizerStyle", in: [2] }, { key: "drawInactiveBlocks", in: [true] }] },
        { key: "vizColorFlow", type: "flow", label: "Color flow", hint: "Used with colors from the album cover, set on the Lyrics page." },
        { key: "vizColorByLevel", type: "bool", label: "Color each bar by how loud it is", hint: "Peak bars and floating dots." },
        { key: "vizGlow", type: "int", label: "Glow", min: 0, max: 100, off: "Off" },
        { key: "vizGlowColorMode", type: "combo", label: "Glow color", options: ["Same as the bars", "The first bar color", "White"], when: { key: "vizGlow", in: "positive" } }
    ] },
    { id: "reaction", title: "Reaction to the music", desc: "How quickly and how strongly the bars follow the sound.", rows: [
        { key: "vizSmoothing", type: "int", label: "Smoothing", min: 0, max: 100, off: "Off" },
        { key: "vizReleaseMs", type: "int", label: "Fall back after silence (ms)", min: 50, max: 3000, step: 50 },
        { key: "vizPeakFall", type: "int", label: "Peak caps fall speed", min: 0, max: 100 },
        { type: "pair", keys: ["vizBassWeight", "vizTrebleWeight"], label: "Bass and treble (%)", min: 0, max: 300,
          hint: "How strongly the lowest and the highest bars show; the ones between change smoothly. 100 leaves them as they are." },
        { key: "vizTaper", type: "bool", label: "Soften the first and last bars" },
        { key: "vizSpacing", type: "combo", label: "Frequency axis", options: ["As cava (logarithmic)", "Mel", "Linear"],
          hint: "How the bars are spread over the pitch range. Mel follows how the ear hears pitch; linear gives the highs more room." },
        { key: "fadeVizWhenPaused", type: "bool", label: "Fade while paused" }
    ] },
    { id: "panel", title: "Size in a panel", desc: "Only used when the widget sits in a panel.", rows: [
        { key: "expanding", type: "bool", label: "Fill the panel's length", panel: true },
        { key: "length", type: "int", label: "Fixed length (px)", min: 1, max: 9999, when: { key: "expanding", in: [false] }, panel: true },
        { key: "minimumLength", type: "int", label: "Minimum length (px)", min: 1, max: 9999, when: { key: "expanding", in: [true] }, panel: true },
        { key: "fillPanel", type: "bool", label: "Fill the panel's thickness", panel: true }
    ] },
    { id: "position", title: "Position", desc: "Where it sits when the card is off, and in the Icon arrangement. With the card on, its layout places the visualizer.", rows: [
        { type: "pair", keys: ["vizWidthPct", "vizHeightPct"], label: "Width and height (%)", min: 0, max: 100 },
        { type: "align", keys: ["vizHAlign", "vizVAlign"], label: "Place" },
        { type: "pair", keys: ["vizOffsetX", "vizOffsetY"], label: "Move right / down (px)", min: -4000, max: 4000, step: 5 }
    ] }
]

// ---- Audio input (the capture is done by cava)
const audio = [
    { id: "input", title: "Where the sound comes from", desc: "Leave these alone unless the visualizer is blank or follows the wrong sound.", open: true, rows: [
        { key: "inputMethod", type: "combo", label: "Method", values: ["", "oss", "pipewire", "sndio", "jack", "pulse", "alsa", "portaudio", "fifo", "shmem"],
          options: ["Default", "OSS", "PipeWire", "Sndio", "JACK", "PulseAudio", "ALSA", "PortAudio", "FIFO", "shmem"],
          hint: "How cava captures sound. Default picks the first one cava was built with: oss, pipewire, sndio, jack, pulse, alsa, portaudio, fifo." },
        { key: "inputSource", type: "source", label: "Source", hint: "Empty (auto) uses the monitor of the default output, so everything you hear. PipeWire and Pulse: the name of a device. ALSA: the capture device. FIFO: the path of the file." },
        { key: "sampleRate", type: "int", label: "Sample rate (Hz)", min: 1, max: 192000, step: 1000 },
        { key: "sampleBits", type: "int", label: "Sample bits", min: 8, max: 32, step: 8, hint: "Only for fifo, pipewire, sndio and oss." },
        { key: "inputChannels", type: "int", label: "Channels", min: 2, max: 4, hint: "Only for pipewire, sndio, oss and jack." },
        { key: "autoconnect", type: "int", label: "Auto connect", min: 2, max: 4, hint: "Only for jack." },
        { key: "active", type: "bool", label: "Keep the capture active", hint: "Pipewire only. Forces the node to always process, which helps monitoring sources when no other app is active." },
        { key: "remix", type: "bool", label: "Remix channels", hint: "Pipewire only. Remix audio channels to match cava's channel count; useful for surround sound." },
        { key: "virtual", type: "bool", label: "Virtual node", hint: "Pipewire only. Avoids recording notifications from the desktop." }
    ] },
    { id: "output", title: "What is drawn", desc: "How the sound is turned into bars.", rows: [
        { key: "framerate", type: "int", label: "Frame rate", min: 1, max: 144 },
        { key: "barCount", type: "int", label: "Number of bars", min: 1, max: 512, hint: "Worked out automatically for the visualizer style." },
        { key: "outputChannels", type: "combo", label: "Channels shown", values: ["mono", "stereo"], options: ["Mono", "Stereo"],
          hint: "Mono: lowest to highest from left to right. Stereo: both channels mirrored, low notes in the middle." },
        { key: "monoOption", type: "combo", label: "Which channel", values: ["left", "right", "average"], options: ["Left", "Right", "Average"], when: { key: "outputChannels", in: ["mono"] } },
        { key: "reverse", type: "bool", label: "Reverse the frequencies" },
        { key: "waveform", type: "bool", label: "Waveform instead of spectrum", hint: "Takes precedence over the simulate waveform option." }
    ] },
    { id: "level", title: "Level and range", desc: "How loud counts as full, and which pitches are shown.", rows: [
        { key: "autoSensitivity", type: "int", label: "Automatic sensitivity", min: 0, max: 10, off: "Off", hint: "Lowers the sensitivity when the bars peak and raises it slowly while they do not. 1 is normal; higher is faster." },
        { key: "sensitivityEnabled", type: "bool", label: "Set the sensitivity myself" },
        { key: "sensitivity", type: "int", label: "Sensitivity (%)", min: 1, max: 999, when: { key: "sensitivityEnabled", in: [true] }, hint: "With automatic sensitivity on this is only the starting value." },
        { type: "pair", keys: ["lowerCutoffFreq", "higherCutoffFreq"], label: "Pitch range (Hz)", min: 1, max: 22000, step: 100, hint: "The lowest and highest pitch the bars show." },
        { key: "noiseReduction", type: "int", label: "Noise reduction", min: 0, max: 100, hint: "Smooths the raw signal. 100 is very slow and smooth, 0 is fast and noisy." },
        { key: "monstercat", type: "bool", label: "Monstercat smoothing" },
        { key: "waves", type: "bool", label: "Waves", hint: "Used with Monstercat smoothing.", when: { key: "monstercat", in: [true] } }
    ] },
    { id: "eq", title: "Equalizer", desc: "Raise or lower parts of the pitch range. More bands give more precision.", rows: [
        { key: "eqEnabled", type: "bool", label: "Use the equalizer" },
        { key: "eq", type: "eq", label: "Bands", when: { key: "eqEnabled", in: [true] } }
    ] }
]

// ---- Card
const cardSections = [
    { id: "layout", title: "Layout", desc: "How the whole card is arranged. The lyrics and the visualizer keep their own looks (the Lyrics and Visualizer pages); the card decides where this arrangement puts them.", open: true, rows: [
        {"key":"layoutMode","type":"combo","label":"Layout","options":["Classic","Mirrored","Inline","Hero wave","Stacked","Orbit","Poster","Slim strip","Compact (no art)","Icon (cover in a progress ring)"],"values":[2,3,4,5,6,7,8,9,10,11],"hint":"How the cover, text, buttons, seek bar and lyrics are arranged. The card itself is turned on on the General page. The layout places the visualizer and the lyrics; their own Position settings apply when there is no card."},
        {"key":"cardAccentSource","type":"combo","label":"Accent color","options":["Same as the lyrics","The Plasma accent","A color of my own"],"hint":"The color of the seek bar, the glow and the rings. \"Same as the lyrics\" is the album cover's color when \"Use colors from the album cover\" is on (Lyrics page, Colors), and the lyric color otherwise."},
        {"key":"customAccent","type":"color","label":"My accent","when":{"key":"cardAccentSource","in":[2]}}
    ] },
    { id: "surface", title: "Background and glow", desc: "What the card is drawn on, its corners, and how it glows with the music.", rows: [
        {"key":"cardSurface","type":"combo","label":"Background","options":["None","Color","Art backdrop","Glass","Liquid glass","Atmosphere","Solid"],"hint":"Art backdrop blurs and dims the cover. Glass is a frosted pane over it. Liquid glass shows the cover through a lens that follows the pointer. Atmosphere lets the cover's colors bleed in from the corners."},
        {"key":"panelColor","type":"color","alpha":true,"label":"Color","when":{"key":"cardSurface","in":[1,6]}},
        {"key":"glassTint","type":"combo","label":"Glass tint","options":["Clear","Dark","Light","The accent"],"when":{"key":"cardSurface","in":[3]}},
        {"key":"surfaceBlur","type":"int","label":"Blur","min":0,"max":100,"when":{"key":"cardSurface","in":[2,3]}},
        {"key":"surfaceDim","type":"int","label":"Darken","min":0,"max":100,"when":{"key":"cardSurface","in":[2,3,4]}},
        {"key":"compositorGlass","type":"bool","label":"Blur the desktop behind the card (KWin)","when":{"key":"cardSurface","in":[3,4]},"hint":"Lets Plasma draw its own blurred background behind a glass card. It needs KWin's Blur effect to be on (System Settings, Desktop Effects), and shows Plasma's frame around the card."},
        {"key":"panelRadius","type":"int","label":"Corner radius","min":0,"max":200,"when":{"key":"cardSurface","in":[1,2,3,4,5,6]}},
        {"key":"surfaceGrain","type":"int","label":"Film grain","min":0,"max":100,"offText":"Off","when":{"key":"cardSurface","in":[1,2,3,4,5,6]}},
        {"key":"surfaceShadow","type":"bool","label":"Shade the bottom edge","when":{"key":"cardSurface","in":[1,2,3,4,5,6]}},
        {"key":"surfaceEdge","type":"bool","label":"Light edge","when":{"key":"cardSurface","in":[1,2,3,4,5,6]}},
        {"key":"panelGlow","type":"int","label":"Edge glow with the bass","min":0,"max":100,"offText":"Off","hint":"The card's edge lights up with the bass of the music. Needs the visualizer to be on."},
        {"key":"ambientGlow","type":"int","label":"Glow around the card","min":0,"max":100,"offText":"Off","hint":"A soft glow in the visualizer's color around the widget. Needs the visualizer to be on."}
    ] },
    { id: "cover", title: "Cover", desc: "The album picture.", rows: [
        {"key":"artShape","type":"combo","label":"Shape","options":["Sharp","Rounded","Squircle","Circle","Vinyl record","CD"]},
        {"key":"artFormat","type":"combo","label":"Format","options":["Square","Wide (4:3)"],"when":{"key":"artShape","in":[0,1,2]}},
        {"key":"artSize","type":"int","label":"Size (px)","min":32,"max":400},
        {"key":"artBorder","type":"int","label":"Border (px)","min":0,"max":8,"offText":"None"},
        {"key":"artGlow","type":"int","label":"Glow","min":0,"max":100,"offText":"Off"},
        {"key":"artTilt","type":"bool","label":"Tilt it"},
        {"key":"artReflect","type":"bool","label":"Reflection"},
        {"key":"artGreyPaused","type":"bool","label":"Gray while paused"},
        {"key":"artSpin","type":"bool","label":"Records and CDs turn while playing","when":{"key":"artShape","in":[4,5]}},
        {"key":"artSparks","type":"bool","label":"Sparks fly off the cover on every beat (needs the visualizer)"},
        {"key":"artThumbnail","type":"combo","label":"YouTube videos","options":["Use the player's cover (the video's picture if there is none)","Always use the video's own picture"]},
        {"key":"artFallback","type":"combo","label":"With no picture","options":["A music note","The first letter of the title","Color only"]},
        {"key":"artClick","type":"combo","label":"Click on the cover","options":["Nothing","Play / pause","Show the details"]}
    ] },
    { id: "buttons", title: "Buttons", desc: "Previous, play and pause, next.", rows: [
        {"key":"controlsShow","type":"combo","label":"Show","options":["Never","When the pointer is over the card","Always"]},
        {"key":"dockStyle","type":"combo","label":"Look","options":["Glass","Soft","Outline","Tinted","Bare","Accent play button","My own QML file"],"when":{"key":"controlsShow","in":[1,2]}},
        {"key":"customButtonsFile","type":"file","folder":"buttons","label":"Buttons file","when":{"key":"dockStyle","in":[6]}},
        {"key":"controlsColorSource","type":"combo","label":"Color","options":["The card's accent","The text color","The Plasma accent","A color of my own"],"when":{"key":"controlsShow","in":[1,2]}},
        {"key":"customControlColor","type":"color","label":"My button color","when":{"key":"controlsColorSource","in":[3]}},
        {"key":"showSkip","type":"bool","label":"Previous and next","when":{"key":"controlsShow","in":[1,2]}},
        {"key":"showShuffleRepeat","type":"bool","label":"Shuffle and repeat","when":{"key":"controlsShow","in":[1,2]}}
    ] },
    { id: "seek", title: "Seek bar", desc: "The progress of the song, and how to jump in it.", rows: [
        {"key":"progressStyle","type":"combo","label":"Style","options":["None","Sleek","Minimal","Glow pulse","Pill","Waveform","Squiggle","Segmented","Dotted","Capsule","Time only","Ring round the cover","My own QML file"]},
        {"key":"customProgressFile","type":"file","folder":"progress","label":"Seek bar file","when":{"key":"progressStyle","in":[12]}},
        {"key":"progressColorSource","type":"combo","label":"Color","options":["The card's accent","The text color","The Plasma accent","A color of my own"]},
        {"key":"customProgressColor","type":"color","label":"My seek bar color","when":{"key":"progressColorSource","in":[3]}},
        {"key":"timeLabels","type":"combo","label":"Times","options":["Off","Elapsed and total","Elapsed and remaining"]},
        {"key":"seekHover","type":"bool","label":"Show the time under the pointer"},
        {"key":"showChapters","type":"bool","label":"Mark the chapters (from a .chapters or .cue file beside the song)"},
        {"key":"reactiveProgress","type":"bool","label":"The glow style pulses with the beat"},
        {"key":"wheelSeekSec","type":"int","label":"Mouse wheel on the bar (s)","min":0,"max":60,"offText":"Off"},
        {"key":"doubleClickSkip","type":"bool","label":"Double click jumps 10 s (left back, right forward)"}
    ] },
    { id: "text", title: "Title and details", desc: "The song's name, and the extra information about it.", rows: [
        {"key":"trackTextStyle","type":"combo","label":"Look","options":["Plain","Shadow","Frosted plate"]},
        {"key":"titleSize","type":"int","label":"Title size (px)","min":9,"max":48},
        {"key":"textAlign","type":"combo","label":"Alignment","options":["By the layout","Left","Center","Right"]},
        {"key":"trackShowAlbum","type":"bool","label":"Show the album"},
        {"key":"showSource","type":"bool","label":"Show which player it is"},
        {"key":"showPlayerSwitch","type":"bool","label":"A button to switch players (when more than one plays)"},
        {"key":"trackScroll","type":"bool","label":"Scroll long titles"},
        {"key":"trackDetails","type":"combo","label":"Details","options":["Off","Tooltip","Drawer under the text","Flip the cover"],"hint":"Song, credits, release and playback details. A drawer opens when the text is clicked; flip turns the cover over when the pointer rests on it."},
        {"key":"onlineInfo","type":"bool","label":"Look up the song online (release year, label, artist text)","when":{"key":"trackDetails","in":[1,2,3]},"hint":"Off by default. When on, the song's title, artist, album and length are sent to MusicBrainz and the artist's name to English Wikipedia."},
        {"key":"detailYear","type":"bool","label":"Show: Year","when":{"key":"onlineInfo","in":"positive"}},
        {"key":"detailLabel","type":"bool","label":"Show: Record label","when":{"key":"onlineInfo","in":"positive"}},
        {"key":"detailCountry","type":"bool","label":"Show: Country","when":{"key":"onlineInfo","in":"positive"}},
        {"key":"detailTags","type":"bool","label":"Show: Tags","when":{"key":"onlineInfo","in":"positive"}},
        {"key":"detailAbout","type":"bool","label":"Show: Text about the artist","when":{"key":"onlineInfo","in":"positive"}}
    ] },
    { id: "poster", title: "Poster arrangement", desc: "Only for the Poster arrangement. The music behind the title uses the style chosen on the Visualizer page.", rows: [
        {"key":"posterLines","type":"int","label":"Title lines","min":1,"max":3,"when":{"key":"layoutMode","in":[8]}},
        {"key":"posterVizBehind","type":"bool","label":"Music behind the title","when":{"key":"layoutMode","in":[8]}},
        {"key":"posterVizOpacity","type":"int","label":"Music strength (%)","min":5,"max":100,"when":{"key":"layoutMode","in":[8]}},
        {"key":"posterClock","type":"bool","label":"Show the time of day","when":{"key":"layoutMode","in":[8]}}
    ] },
    { id: "orbit", title: "Orbit arrangement", desc: "Only for the Orbit arrangement. The ring is the visualizer, in the style chosen on the Visualizer page.", rows: [
        {"key":"orbitCenter","type":"combo","label":"In the middle","options":["The cover","The cover and the title","The title","Nothing"],"when":{"key":"layoutMode","in":[7]}},
        {"key":"orbitRotate","type":"bool","label":"The ring turns slowly","when":{"key":"layoutMode","in":[7]}},
        {"key":"orbitCoverPulse","type":"bool","label":"The cover breathes with the bass","when":{"key":"layoutMode","in":[7]}},
        {"key":"orbitGlowRing","type":"bool","label":"A glowing ring","when":{"key":"layoutMode","in":[7]}}
    ] },
    { id: "behavior", title: "Pointer", desc: "What the mouse does over the card.", rows: [
        {"key":"scrollVolume","type":"bool","label":"Scroll over the card to change the volume"},
        {"key":"hoverLift","type":"bool","label":"The card lifts a little when the pointer is on it"}
    ] },
    { id: "panel", title: "In a panel", desc: "Only used when the widget sits in a panel (a bar at the edge of the screen), not on the desktop.", rows: [
        {"key":"panelMode","type":"combo","label":"In a panel","options":["The card","A small pill that opens the card","The card when there is room, else the pill"],"hint":"On the desktop the widget is always the card. In a panel it can be the card, a pill, or either depending on the panel's thickness."},
        {"key":"panelOrientation","type":"combo","label":"Turn the card","options":["By itself in a vertical panel","Never","Left","Right"],"when":{"key":"panelMode","in":[0,2]}},
        {"key":"panelCardSizing","type":"combo","label":"Size of the card","options":["Fit the panel's thickness","A fixed scale"],"when":{"key":"panelMode","in":[0,2]}},
        {"key":"panelCardScale","type":"int","label":"Scale (%)","min":50,"max":400,"when":{"key":"panelMode","in":[0,2]}},
        {"key":"pillContent","type":"combo","label":"Pill text","options":["Title and artist","Title","Artist","Nothing"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillArt","type":"bool","label":"Cover in the pill","when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillEq","type":"combo","label":"Small visualizer","options":["None","Moving bars","Live (uses cava)"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillProgress","type":"combo","label":"Progress","options":["None","A line under the text","A ring round the cover"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillControls","type":"combo","label":"Buttons","options":["None","Play / pause","Previous, play / pause, next"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillControlsOnHover","type":"bool","label":"Show the buttons only on hover","when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillMaxWidth","type":"int","label":"Longest the pill gets (px)","min":80,"max":800,"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillScroll","type":"bool","label":"Scroll a long title","when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillPopupTrigger","type":"combo","label":"Open the card by","options":["Clicking","Hovering","Clicking or hovering"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillClick","type":"combo","label":"Clicking the pill","options":["Opens the card","Plays or pauses","Skips to the next song"],"when":{"key":"panelMode","in":[1,2]},"hint":"A middle click always plays or pauses."}
    ] },
    { id: "pill", title: "Pill look", desc: "Only used when the widget is a small pill in a panel.", rows: [
        {"key":"pillArtShape","type":"combo","label":"Cover shape","options":["Sharp","Rounded","Squircle","Circle","Vinyl record","CD"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillArtBorder","type":"int","label":"Cover border (px)","min":0,"max":8,"offText":"None","when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillArtGlow","type":"int","label":"Cover glow","min":0,"max":100,"offText":"Off","when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillTextStyle","type":"combo","label":"Text","options":["Plain","Shadow"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillDockStyle","type":"combo","label":"Button look","options":["Glass","Soft","Outline","Tinted","Bare","Accent play button"],"when":{"key":"panelMode","in":[1,2]}},
        {"key":"pillEqStyle","type":"combo","label":"Live visualizer","options":["Bars","Wave"],"when":{"key":"pillEq","in":[2]}}
    ] }
]

// ---- Sources
const sources = [
    { id: "local", title: "Your own files", desc: "Lyrics that sit beside your music files.", open: true, rows: [
        { key: "localLyrics", type: "bool", label: "Use lyrics saved beside the song", hint: "A .lrc file with the song's name, or lyrics saved inside the file's tags." },
        { key: "localLyricsFolder", type: "text", label: "Also look in this folder", placeholder: "Empty: only beside the song", when: { key: "localLyrics", in: [true] } }
    ] },
    { id: "next", title: "Next songs", desc: "Lyrics can be prepared before a song starts.", rows: [
        { key: "prefetchCount", type: "int", label: "Prepare lyrics for the next", min: 0, max: 5, off: "Off", unit: { suffix: " songs" }, hint: "Needs the Spotify app queue or the YouTube Music queue below." }
    ] },
    { id: "spotify", title: "Spotify", desc: "Read the queue and lyrics from the Spotify app.", rows: [
        { key: "spotifyAppQueue", type: "bool", label: "Get lyrics and the queue from the Spotify app", hint: "Needs Spotify started with a debug port (Spicetify does this). It only reads; nothing in Spotify is changed." },
        { key: "spotifyDebugPort", type: "int", label: "Port", min: 1024, max: 65535, when: { key: "spotifyAppQueue", in: [true] } },
        { type: "spotify", label: "Check", when: { key: "spotifyAppQueue", in: [true] } }
    ] },
    { id: "browser", title: "YouTube Music and browsers", desc: "A small browser extension sends the queue to this widget. It only talks to this computer.", rows: [
        { key: "browserQueue", type: "bool", label: "Get the queue from YouTube Music" },
        { key: "browserQueuePort", type: "int", label: "Port", min: 1024, max: 65535, when: { key: "browserQueue", in: [true] } },
        { type: "browser", label: "Browser extension" }
    ] },
    { id: "players", title: "Players", desc: "Which players the widget follows.", rows: [
        { key: "anyPlayer", type: "bool", label: "Follow any media player", hint: "Off: Spotify and the websites below, in Chrome. On: also VLC, mpv, Strawberry, Elisa, Cider (Apple Music) and any other player that reports what it plays." },
        { key: "allowedSites", type: "sites", label: "Websites a browser may play music from" }
    ] }
]

const pages = [
    { id: "general", title: "General", icon: "configure", subtitle: "What the widget shows, its size, and when it rests.", sections: general },
    { id: "lyrics", title: "Lyrics", icon: "format-text-bold", subtitle: "How the lines look, what is shown and when, and where it sits.", sections: lyrics },
    { id: "visualizer", title: "Visualizer", icon: "audio-input-microphone", subtitle: "The bars, waves and effects that follow the music.",
      banner: { key: "showVisualizer", text: "The visualizer is off, so nothing here shows yet.", button: "Turn it on" }, preview: "viz", sections: visualizer },
    { id: "audio", title: "Audio input", icon: "audio-input-line", subtitle: "Where the visualizer hears the music from, and how it reads it.",
      banner: { key: "showVisualizer", text: "The visualizer is off, so nothing here shows yet.", button: "Turn it on" }, sections: audio },
    { id: "card", title: "Card", icon: "view-media-playlist", subtitle: "The cover, title, buttons and seek bar around the lyrics.",
      banner: { key: "showCard", text: "The card is off: the widget shows only the lyrics, and the visualizer if it is on.", button: "Turn it on" }, preview: "card", sections: cardSections },
    { id: "sources", title: "Sources", icon: "folder-music", subtitle: "Where lyrics and songs come from.", sections: sources }
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
