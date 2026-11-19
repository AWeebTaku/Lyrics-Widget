import QtQuick
import QtQuick.Controls as QQC2
import org.lyricwidget
import "../audioviz/components"
import "../audioviz/code/enum.js" as Enum
import "../audioviz/code/globals.js" as Globals
import "../audioviz/code/utils.js" as Utils
import "palettes.js" as Palettes

// A live preview for the settings: the chosen style drawn from a made-up spectrum (a kick every half second and a
// drifting top end), so the settings can be judged with no music playing. It uses the same analysis and drawing as the
// widget; `s` is a plain object of the settings in force (style, sizes and the reaction / color options).
Rectangle {
    id: root
    property var s: ({})
    property bool still: false
    // Minimal by default: one still frame, redrawn when a setting changes. The checkbox (or `animate`) runs it live at 15 frames a second.
    property bool animate: false
    property bool showToggle: true
    readonly property bool frozen: still || !animate
    implicitHeight: 150
    color: "#181c26"
    radius: 8
    clip: true

    readonly property int bars: 56
    property var raw: []
    readonly property bool gpu: Enum.isGpuStyle(s.visualizerStyle ?? 1)

    VizAnalysis {
        id: ana
        smoothing: root.s.vizSmoothing ?? 0
        releaseMs: root.s.vizReleaseMs ?? 350
        peakFall: root.s.vizPeakFall ?? 40
        bassWeight: root.s.vizBassWeight ?? 100
        trebleWeight: root.s.vizTrebleWeight ?? 100
        taper: root.s.vizTaper ?? false
        spacing: root.s.vizSpacing ?? 0
    }
    property real hue: 0
    function step(frozenFrame) {
        {
            const t = frozenFrame ? 0 : Date.now() - t0, ph = (t % 500) / 500, kick = Math.exp(-ph * 6)
            const out = []
            for (let i = 0; i < root.bars; ++i) {
                const f = i / (root.bars - 1)
                const base = 0.28 + 0.2 * Math.sin(i * 0.5 + t / 400) + 0.12 * Math.sin(t / 900 + f * 6)
                out.push(Math.round(100 * Math.max(0, Math.min(1, base * (1 - f * 0.45) + (1 - f) * (1 - f) * kick * 0.8))))
            }
            ana.feed(out, 100)
            root.raw = out
            if ((root.s.vizColorMode ?? 0) >= 2 && !frozenFrame)
                root.hue = (root.hue + (root.s.vizRainbowSpeed ?? 30) / 1000 * 0.12 + ((root.s.vizColorMode ?? 0) === 3 ? ana.high * 0.03 : 0)) % 1
        }
    }
    property double t0: Date.now()
    Timer { interval: 66; repeat: true; running: root.visible && !root.frozen; onTriggered: root.step(false) }
    // a still frame: a few steps so the smoothing settles, again whenever a setting changes
    function stillFrame() { if (frozen) for (let i = 0; i < 6; ++i) step(true) }
    onSChanged: stillFrame()
    onFrozenChanged: stillFrame()
    onBarsChanged: stillFrame()
    Component.onCompleted: stillFrame()

    function colorsCfg() {
        const base = Utils.mergeConfigs(Globals.baseBarColors, {})
        const m = root.s.vizColorMode ?? 0
        if (m === 0) return base
        const list = m === 1 ? Palettes.paletteColors(root.s.vizPalette ?? 0) : Palettes.rainbow(root.hue, 6)
        return Object.assign({}, base, { sourceType: Enum.ColorSourceType.List, list: list, colorsOrientation: 0, reverseList: false })
    }
    readonly property var barCfg: { root.hue; root.s; return colorsCfg() }
    readonly property bool analysed: (s.vizSmoothing ?? 0) > 0 || (s.vizBassWeight ?? 100) !== 100 || (s.vizTrebleWeight ?? 100) !== 100
                                     || (s.vizTaper ?? false) || (s.vizSpacing ?? 0) !== 0

    PlasmaShader {
        anchors.fill: parent
        visible: root.gpu
        shaderName: (root.s.visualizerStyle ?? 1) === Enum.VisualizerStyles.Terrain ? "terrain" : (root.s.visualizerStyle ?? 1) === Enum.VisualizerStyles.Tunnel ? "tunnel" : "plasma"
        bass: ana.bass; mid: ana.mid; high: ana.high
        bandsA: Qt.vector4d(ana.bands[0] ?? 0, ana.bands[1] ?? 0, ana.bands[2] ?? 0, ana.bands[3] ?? 0)
        bandsB: Qt.vector4d(ana.bands[4] ?? 0, ana.bands[5] ?? 0, ana.bands[6] ?? 0, ana.bands[7] ?? 0)
        still: root.frozen
        colorA: "#ff8a5c"; colorB: "#d6457f"; colorC: "#6a2c91"
    }
    Item {
        id: holder
        readonly property bool sideways: (root.s.orientation ?? 1) >= 2
        anchors.centerIn: parent
        width: (sideways ? root.height : root.width) - 16
        height: (sideways ? root.width : root.height) - 16
        visible: !root.gpu && (root.s.visualizerStyle ?? 1) !== Enum.VisualizerStyles.Custom
    Visualizer {
        id: vv
        anchors.fill: parent
        visualizerStyle: root.s.visualizerStyle ?? 1
        circleMode: false; circleModeSize: 0.5; circleModeFill: false
        barWidth: root.s.barWidth ?? 2
        blockHeight: root.s.blockHeight ?? 2; blockSpacing: root.s.blockSpacing ?? 2; barGap: root.s.barGap ?? 5
        centeredBars: root.s.centeredBars ?? false; waveMode: root.s.waveMode ?? 0
        roundedBars: root.s.roundedBars ?? false; fillWave: root.s.fillWave ?? true
        barColorsCfg: root.barCfg
        waveFillColorsCfg: Utils.mergeConfigs(Globals.baseWaveFillColors, {})
        inactiveBlockColorsCfg: Utils.mergeConfigs(Globals.baseInactiveBlockColors, {})
        drawInactiveBlocks: false; fixVertical: false; waveSimulateWaveform: false; waveform: false
        values: root.analysed ? ana.levels : root.raw
        peaks: ana.peaks
        bass: ana.bass
        beat: ana.beat
        reduced: root.frozen
        byLevel: root.s.vizColorByLevel ?? false
        spin: root.s.orbitRotate ?? true
        ribbonCurve: (root.s.ribbonCurvature ?? 100) / 100
        ribbonFull: (root.s.ribbonFullness ?? 100) / 100

        // the side the bars grow from (Settings, Visualizer, Style, Orientation), as in the widget itself
        property var orientationTop: Rotation { origin.x: Math.floor(vv.width / 2); origin.y: Math.floor(vv.height / 2); axis { x: 1; y: 0; z: 0 } angle: 180 }
        property var orientationLeft: Rotation { origin.x: Math.floor(vv.width / 2); origin.y: Math.floor(vv.height / 2); angle: 90 }
        property var orientationRight: Rotation { origin.x: Math.floor(vv.width / 2); origin.y: Math.floor(vv.height / 2); angle: -90 }
        transform: {
            const o = root.s.orientation ?? 1, t = []
            if (o === 0) t.push(orientationTop)
            if (o === 2) t.push(orientationLeft)
            if (o === 3) { t.push(orientationRight); t.push(orientationTop) }
            return t
        }
    }
    }
    Text {
        visible: (root.s.visualizerStyle ?? 1) === Enum.VisualizerStyles.Custom
        anchors.centerIn: parent
        color: "white"; opacity: 0.6
        text: "Custom visualizer: shown in the widget"
    }
    QQC2.CheckBox {
        visible: root.showToggle && !root.still
        anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
        text: qsTr("Animate")
        checked: root.animate
        onToggled: root.animate = checked
    }
}
