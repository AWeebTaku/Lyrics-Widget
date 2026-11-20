// The audio visualizer: cava (the sound analysis) feeding the canvas renderer in audioviz/.
// Created/destroyed by a Loader in main.qml, so cava only runs while it is needed.
import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.lyricwidget
import "viz/palettes.js" as Palettes
import "viz"
import "audioviz"
import "audioviz/components"
import "audioviz/code/enum.js" as Enum
import "audioviz/code/globals.js" as Globals
import "audioviz/code/utils.js" as Utils

Item {
    id: root
    clip: !Plasmoid.configuration.debugMode

    readonly property bool hasError: cava.hasError
    readonly property string error: cava.error
    readonly property bool sideways: [Enum.Orientation.Left, Enum.Orientation.Right].includes(Plasmoid.configuration.orientation)
    readonly property real minimumDimension: Math.min(width, height)

    // the style to draw: a layout may ask for one (the orbit layout wants the ring); "simple rendering" has no GPU styles
    property int styleOverride: -1
    property int barWidthOverride: -1      // a small visualizer (the panel pill) sets its own bars
    property int barGapOverride: -1
    readonly property int barW: barWidthOverride >= 0 ? barWidthOverride : Plasmoid.configuration.barWidth
    readonly property int barG: barGapOverride >= 0 ? barGapOverride : Plasmoid.configuration.barGap
    readonly property int style: {
        const st = styleOverride >= 0 ? styleOverride : Plasmoid.configuration.visualizerStyle
        return Plasmoid.configuration.simpleRender && (Enum.isGpuStyle(st) || st === Enum.VisualizerStyles.Custom) ? Enum.VisualizerStyles.Wave : st
    }

    property var logger: Logger.create(Plasmoid.configuration.debugMode ? LoggingCategory.Debug : LoggingCategory.Info)

    // ---- bar count / cava output range from the available size (as the original main.qml)
    // what the lyric widget's effects read (main.qml): the music's levels and the beat
    readonly property real bass: analysis.bass
    readonly property real mid: analysis.mid
    readonly property real high: analysis.high
    readonly property real beat: analysis.beat
    readonly property bool reduced: Plasmoid.configuration.reducedMotion || Plasmoid.configuration.batterySaver

    // smoothing, peak caps, bass / mid / high and the beat come from the bands cava gives
    VizAnalysis {
        id: analysis
        smoothing: Plasmoid.configuration.vizSmoothing
        releaseMs: Plasmoid.configuration.vizReleaseMs
        peakFall: Plasmoid.configuration.vizPeakFall
        bassWeight: Plasmoid.configuration.vizBassWeight
        trebleWeight: Plasmoid.configuration.vizTrebleWeight
        taper: Plasmoid.configuration.vizTaper
        spacing: Plasmoid.configuration.vizSpacing
        lowHz: Plasmoid.configuration.lowerCutoffFreq
        highHz: Plasmoid.configuration.higherCutoffFreq
    }
    Connections {
        target: cava
        function onValuesChanged() { analysis.feed(cava.values, root.asciiMaxRange) }
    }
    // the analysed bars replace cava's own only when one of its settings is in use
    readonly property bool analysed: Plasmoid.configuration.vizSmoothing > 0 || Plasmoid.configuration.vizBassWeight !== 100
                                     || Plasmoid.configuration.vizTrebleWeight !== 100 || Plasmoid.configuration.vizTaper
                                     || Plasmoid.configuration.vizSpacing !== 0

    property int barGap: {
        if (Enum.isLineStyle(root.style))
            return Math.max(1, root.barG);
        return root.barG;
    }
    property int barCount: {
        let bars = 1;
        const span = Plasmoid.configuration.circleMode ? minimumDimension : (sideways ? height : width);
        if (Enum.isLineStyle(root.style))
            bars = Math.floor((span + barGap) / barGap);
        else
            bars = Math.floor((span + barGap) / (root.barW + barGap));
        if (Plasmoid.configuration.outputChannels === "stereo")
            bars = Utils.makeEven(bars);
        if (Enum.isLineStyle(root.style))
            bars = Math.max(2, bars);
        return bars;
    }
    property int asciiMaxRange: sideways ? width : height

    onBarCountChanged: Qt.callLater(() => resizeDebounce.restart())
    onAsciiMaxRangeChanged: Qt.callLater(() => resizeDebounce.restart())
    Timer {
        id: resizeDebounce
        interval: 50
        onTriggered: {
            cava.barCount = root.barCount;
            cava.asciiMaxRange = root.asciiMaxRange;
        }
    }

    Cava {
        id: cava
        framerate: Plasmoid.configuration.batterySaver ? Math.min(20, Plasmoid.configuration.framerate) : Plasmoid.configuration.framerate
        noiseReduction: Plasmoid.configuration.noiseReduction
        monstercat: Plasmoid.configuration.monstercat
        waves: Plasmoid.configuration.waves
        autoSensitivity: Plasmoid.configuration.autoSensitivity
        sensitivityEnabled: Plasmoid.configuration.sensitivityEnabled
        sensitivity: Plasmoid.configuration.sensitivity
        lowerCutoffFreq: Plasmoid.configuration.lowerCutoffFreq
        higherCutoffFreq: Plasmoid.configuration.higherCutoffFreq
        inputMethod: Plasmoid.configuration.inputMethod
        inputSource: Plasmoid.configuration.inputSource
        sampleRate: Plasmoid.configuration.sampleRate
        sampleBits: Plasmoid.configuration.sampleBits
        inputChannels: Plasmoid.configuration.inputChannels
        autoconnect: Plasmoid.configuration.autoconnect
        active: Plasmoid.configuration.active
        remix: Plasmoid.configuration.remix
        virtual: Plasmoid.configuration.virtual
        outputChannels: root.style === Enum.VisualizerStyles.StereoScope ? "stereo" : Plasmoid.configuration.outputChannels
        monoOption: Plasmoid.configuration.monoOption
        reverse: Plasmoid.configuration.reverse
        waveform: root.style === Enum.VisualizerStyles.StereoScope ? true : Plasmoid.configuration.waveform
        eqEnabled: Plasmoid.configuration.eqEnabled
        eq: Plasmoid.configuration.eq
        idleCheck: Plasmoid.configuration.hideAfterSec > 0
        idleTimer: Plasmoid.configuration.hideAfterSec
        cavaSleepTimer: Math.max(1, Math.min(60, Plasmoid.configuration.hideAfterSec || 5))
        onHasErrorChanged: root.logger.error("cava.hasError:", hasError, error)
    }

    Component.onDestruction: cava.stop()

    // ---- color settings are stored as JSON and merged with the defaults (as the original)
    function mergedColors(raw, base) {
        let stored;
        try {
            stored = JSON.parse(raw);
        } catch (e) {
            logger.error(e, e.stack);
        }
        return Utils.mergeConfigs(base, stored);
    }
    property var barColorsStored: mergedColors(Plasmoid.configuration.barColors, Globals.baseBarColors)
    property var waveFillColorsStored: mergedColors(Plasmoid.configuration.waveFillColors, Globals.baseWaveFillColors)
    property var inactiveBlockColorsCfg: mergedColors(Plasmoid.configuration.inactiveBlockColors, Globals.baseInactiveBlockColors)

    // "Use colors from the album cover" (lyric widget addition): the cover colors replace the configured
    // bar/wave colors while there are some; the stored settings are left alone.
    property var tintColors: []
    property int tintFlow: 0 // see StyledText.flow; 0 = left to right (as the bars are laid out)
    function tinted(cfg) {
        if (tintColors.length === 0)
            return cfg
        // one cover color: a plain color; several: a gradient through all of them
        return tintColors.length === 1
            ? Object.assign({}, cfg, {sourceType: Enum.ColorSourceType.Custom, custom: tintColors[0]})
            : Object.assign({}, cfg, {sourceType: Enum.ColorSourceType.List, list: tintColors, colorsOrientation: tintFlow})
    }
    // Color modes (Settings, Visualizer, Reaction): a palette, or the color wheel turning, or the wheel pushed on by the
    // treble. They replace the configured colors (and the cover colors) while one is chosen.
    property real hueOffset: 0
    Timer {
        interval: 120
        repeat: true
        running: Plasmoid.configuration.vizColorMode >= 2 && !root.reduced
        onTriggered: root.hueOffset = (root.hueOffset + Plasmoid.configuration.vizRainbowSpeed / 1000 * 0.12
                                       + (Plasmoid.configuration.vizColorMode === 3 ? analysis.high * 0.03 : 0)) % 1
    }
    function moded(cfg) {
        const m = Plasmoid.configuration.vizColorMode
        if (m === 0)
            return tinted(cfg)
        const list = m === 1 ? Palettes.paletteColors(Plasmoid.configuration.vizPalette) : Palettes.rainbow(hueOffset, 6)
        return Object.assign({}, cfg, {sourceType: Enum.ColorSourceType.List, list: list, colorsOrientation: tintFlow, reverseList: false})
    }
    property var barColorsCfg: moded(barColorsStored)
    property var waveFillColorsCfg: moded(waveFillColorsStored)

    // Store the merged defaults once (the settings pages read them back), outside any binding.
    Component.onCompleted: {
        const pairs = [["barColors", barColorsStored], ["waveFillColors", waveFillColorsStored],
                       ["inactiveBlockColors", inactiveBlockColorsCfg]];
        let changed = false;
        for (const [key, cfg] of pairs) {
            const str = JSON.stringify(cfg);
            if (Plasmoid.configuration[key] !== str) {
                Plasmoid.configuration[key] = str;
                changed = true;
            }
        }
        if (changed)
            Plasmoid.configuration.writeConfig();
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: root.sideways ? parent.height : parent.width
        height: root.sideways ? parent.width : parent.height
        layer.enabled: glow.visible

        // the GPU styles: three colors picked from the bar colors
        readonly property var plasmaColors: Utils.getColors(root.barColorsCfg, 6, Qt.color("#5b8def"))
        PlasmaShader {
            anchors.fill: parent
            visible: Enum.isGpuStyle(root.style) && !cava.hasError && !cava.idle
            shaderName: root.style === Enum.VisualizerStyles.Terrain ? "terrain" : root.style === Enum.VisualizerStyles.Tunnel ? "tunnel" : "plasma"
            bass: analysis.bass
            mid: analysis.mid
            high: analysis.high
            bandsA: Qt.vector4d(analysis.bands[0] ?? 0, analysis.bands[1] ?? 0, analysis.bands[2] ?? 0, analysis.bands[3] ?? 0)
            bandsB: Qt.vector4d(analysis.bands[4] ?? 0, analysis.bands[5] ?? 0, analysis.bands[6] ?? 0, analysis.bands[7] ?? 0)
            still: root.reduced
            colorA: content.plasmaColors.length ? content.plasmaColors[0] : "#ff8a5c"
            colorB: content.plasmaColors.length ? content.plasmaColors[Math.floor((content.plasmaColors.length - 1) / 2)] : "#d6457f"
            colorC: content.plasmaColors.length ? content.plasmaColors[content.plasmaColors.length - 1] : "#6a2c91"
        }

        // a visualizer written by the user as a QML file (off unless allowed in the settings)
        CustomViz {
            anchors.fill: parent
            visible: root.style === Enum.VisualizerStyles.Custom && !cava.hasError && !cava.idle
            file: Plasmoid.configuration.allowCustomQml ? Plasmoid.configuration.customQmlFile : ""
            values: analysis.levels
            peaks: analysis.peaks
            bass: analysis.bass
            mid: analysis.mid
            high: analysis.high
            beat: analysis.beat
            colors: content.plasmaColors
        }

        Visualizer {
            id: visualizer
            anchors.fill: parent
            visualizerStyle: root.style
            circleMode: Plasmoid.configuration.circleMode
            circleModeSize: Plasmoid.configuration.circleModeSize
            circleModeFill: Plasmoid.configuration.circleModeFill
            barWidth: root.barW
            blockHeight: Plasmoid.configuration.blockHeight
            blockSpacing: Plasmoid.configuration.blockSpacing
            barGap: root.barG
            centeredBars: Plasmoid.configuration.centeredBars
            waveMode: Plasmoid.configuration.waveMode
            roundedBars: Plasmoid.configuration.roundedBars
            fillWave: Plasmoid.configuration.fillWave
            barColorsCfg: root.barColorsCfg
            waveFillColorsCfg: root.waveFillColorsCfg
            inactiveBlockColorsCfg: root.inactiveBlockColorsCfg
            drawInactiveBlocks: Plasmoid.configuration.drawInactiveBlocks
            waveSimulateWaveform: Plasmoid.configuration.waveSimulateWaveform
            waveform: Plasmoid.configuration.waveform
            debugMode: Plasmoid.configuration.debugMode
            visible: !cava.hasError && !cava.idle && !Enum.isGpuStyle(root.style) && root.style !== Enum.VisualizerStyles.Custom
            fixVertical: false
            peaks: analysis.peaks
            bass: analysis.bass
            beat: analysis.beat
            reduced: root.reduced
            byLevel: Plasmoid.configuration.vizColorByLevel
            spin: root.styleOverride === Enum.VisualizerStyles.OrbitRing ? Plasmoid.configuration.orbitRotate : true
            ribbonCurve: Plasmoid.configuration.ribbonCurvature / 100
            ribbonFull: Plasmoid.configuration.ribbonFullness / 100
            slow: Plasmoid.configuration.idleThrottle && analysis.silentMs > 3000
            values: {
                let values = [...(root.analysed ? analysis.levels : cava.values)];
                if (Plasmoid.configuration.circleMode && Plasmoid.configuration.outputChannels === "stereo")
                    return Utils.swapChannels(values);
                if (root.style === Enum.VisualizerStyles.Wave
                        && Plasmoid.configuration.pinnedDownSides && !Plasmoid.configuration.circleMode
                        && !Plasmoid.configuration.waveform) {
                    values[0] = 0;
                    values[values.length - 1] = 0;
                }
                return values;
            }

            property var orientationTop: Rotation {
                origin.x: Math.floor(visualizer.width / 2); origin.y: Math.floor(visualizer.height / 2)
                axis { x: 1; y: 0; z: 0 }
                angle: 180
            }
            property var orientationLeft: Rotation {
                origin.x: Math.floor(visualizer.width / 2); origin.y: Math.floor(visualizer.height / 2)
                angle: 90
            }
            property var orientationRight: Rotation {
                origin.x: Math.floor(visualizer.width / 2); origin.y: Math.floor(visualizer.height / 2)
                angle: -90
            }
            transform: {
                const o = Plasmoid.configuration.orientation;
                const t = [];
                if (o === Enum.Orientation.Top) t.push(orientationTop);
                if (o === Enum.Orientation.Left) t.push(orientationLeft);
                if (o === Enum.Orientation.Right) { t.push(orientationRight); t.push(orientationTop); }
                return t;
            }
        }
    }

    // when cava cannot run, say why and what to do instead of showing nothing
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
        visible: cava.hasError
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "#e0e0e0"
        opacity: 0.8
        font.pixelSize: 12
        text: {
            const e = cava.error.toLowerCase()
            if (cava.loadingFailed || e.includes("not found") || e.includes("no such file"))
                return "The visualizer needs cava. Install it (sudo pacman -S cava, sudo apt install cava or sudo dnf install cava), then restart the widget."
            if (e.includes("pipewire") || e.includes("pulse") || e.includes("alsa") || e.includes("input"))
                return "cava could not open the audio input. Pick the input in Settings, Audio input."
            return "cava stopped: " + cava.error.trim().split("\n")[0] + "  (run: bash /usr/share/lyric-widget/doctor.sh)"
        }
    }

    // glow: a blurred copy of the bars drawn over them (off in battery saver)
    MultiEffect {
        id: glow
        anchors.fill: content
        source: content
        visible: Plasmoid.configuration.vizGlow > 0 && !Plasmoid.configuration.batterySaver && !Plasmoid.configuration.simpleRender
        // glow color: as the bars, the first color of the bars, or white
        colorization: Plasmoid.configuration.vizGlowColorMode === 0 ? 0 : 1
        colorizationColor: Plasmoid.configuration.vizGlowColorMode === 1 && content.plasmaColors.length ? content.plasmaColors[0] : "white"
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        brightness: 0.2
        opacity: Plasmoid.configuration.vizGlow / 100
    }
}
