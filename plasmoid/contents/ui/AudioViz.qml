// Embeds the audio visualizer of "Plasma Audio Visualizer" by Luis Bocanegra
// (https://github.com/luisbocanegra/plasma-audio-visualizer, GPL-3.0) in the lyric widget.
// The files under audioviz/ are that widget's, copied as they are (process backend aside);
// this item replaces its main.qml + CompactRepresentation.qml.
// Created/destroyed by a Loader in main.qml, so cava only runs while it is needed.
import QtQuick
import org.kde.plasma.plasmoid
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

    property var logger: Logger.create(Plasmoid.configuration.debugMode ? LoggingCategory.Debug : LoggingCategory.Info)

    // ---- bar count / cava output range from the available size (as the original main.qml)
    property int barGap: {
        if (Plasmoid.configuration.visualizerStyle === Enum.VisualizerStyles.Wave)
            return Math.max(1, Plasmoid.configuration.barGap);
        return Plasmoid.configuration.barGap;
    }
    property int barCount: {
        let bars = 1;
        const span = Plasmoid.configuration.circleMode ? minimumDimension : (sideways ? height : width);
        if (Plasmoid.configuration.visualizerStyle === Enum.VisualizerStyles.Wave)
            bars = Math.floor((span + barGap) / barGap);
        else
            bars = Math.floor((span + barGap) / (Plasmoid.configuration.barWidth + barGap));
        if (Plasmoid.configuration.outputChannels === "stereo")
            bars = Utils.makeEven(bars);
        if (Plasmoid.configuration.visualizerStyle === Enum.VisualizerStyles.Wave)
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
        framerate: Plasmoid.configuration.framerate
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
        outputChannels: Plasmoid.configuration.outputChannels
        monoOption: Plasmoid.configuration.monoOption
        reverse: Plasmoid.configuration.reverse
        waveform: Plasmoid.configuration.waveform
        eqEnabled: Plasmoid.configuration.eqEnabled
        eq: Plasmoid.configuration.eq
        idleCheck: Plasmoid.configuration.hideWhenIdle
        idleTimer: Plasmoid.configuration.idleTimer
        cavaSleepTimer: Plasmoid.configuration.cavaSleepTimer
        onHasErrorChanged: root.logger.error("cava.hasError:", hasError, error)
    }

    Component.onDestruction: cava.stop()

    // ---- colour settings are stored as JSON and merged with the defaults (as the original)
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

    // "Color from the cover" (lyric widget addition): one custom colour replaces the configured
    // bar/wave colours while a cover colour is set; the stored settings are left alone.
    property string tint: ""
    function tinted(cfg) {
        return tint === "" ? cfg : Object.assign({}, cfg, {sourceType: Enum.ColorSourceType.Custom, custom: tint})
    }
    property var barColorsCfg: tinted(barColorsStored)
    property var waveFillColorsCfg: tinted(waveFillColorsStored)

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

        Visualizer {
            id: visualizer
            anchors.fill: parent
            visualizerStyle: Plasmoid.configuration.visualizerStyle
            circleMode: Plasmoid.configuration.circleMode
            circleModeSize: Plasmoid.configuration.circleModeSize
            circleModeFill: Plasmoid.configuration.circleModeFill
            barWidth: Plasmoid.configuration.barWidth
            blockHeight: Plasmoid.configuration.blockHeight
            blockSpacing: Plasmoid.configuration.blockSpacing
            barGap: Plasmoid.configuration.barGap
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
            visible: !cava.hasError && !cava.idle
            fixVertical: false
            values: {
                let values = [...cava.values];
                if (Plasmoid.configuration.circleMode && Plasmoid.configuration.outputChannels === "stereo")
                    return Utils.swapChannels(values);
                if (Plasmoid.configuration.visualizerStyle === Enum.VisualizerStyles.Wave
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
}
