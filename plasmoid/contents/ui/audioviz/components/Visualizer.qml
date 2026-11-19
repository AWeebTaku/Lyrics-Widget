import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "../code/utils.js" as Utils
import "../code/enum.js" as Enum
import "../code/drawCanvas.js" as DrawCanvas
import "../../viz/styles.js" as Styles

Item {
    id: root
    required property int visualizerStyle
    required property bool circleMode
    required property real circleModeSize
    required property int barWidth
    required property int blockHeight
    required property int blockSpacing
    required property int barGap
    required property bool centeredBars
    required property int waveMode
    required property bool roundedBars
    required property bool fillWave
    required property var barColorsCfg
    required property var waveFillColorsCfg
    required property var inactiveBlockColorsCfg
    required property bool drawInactiveBlocks
    required property bool fixVertical
    required property bool waveSimulateWaveform
    required property bool circleModeFill
    required property bool waveform
    property list<int> values
    property list<int> peaks       // falling caps, same scale as values (VizAnalysis)
    property real bass: 0          // 0..1
    property real beat: 0          // 1 at a beat, then falling
    property bool reduced: false   // no motion that is not the music itself
    property bool byLevel: false   // colour each bar by how loud it is
    property bool spin: true        // the orbit ring turns
    property real ribbonCurve: 1    // how much the ribbons sway
    property real ribbonFull: 1     // how full they are
    property bool slow: false      // long silence: repaint twice a second instead of every frame
    property bool debugMode: false

    Rectangle {
        id: kirigamiColorItem
        opacity: 0
        height: 1
        width: height
        Kirigami.Theme.colorSet: Kirigami.Theme[root.barColorsCfg.systemColorSet]
    }

    Rectangle {
        id: kirigamiColorItem2
        opacity: 0
        height: 1
        width: height
        Kirigami.Theme.colorSet: Kirigami.Theme[root.waveFillColorsCfg.systemColorSet]
    }
    Rectangle {
        color: Kirigami.Theme.highlightColor
        opacity: 0.1
        visible: root.debugMode
        width: canvas.width
        height: canvas.height
        anchors.centerIn: parent
    }
    Canvas {
        id: canvas
        anchors.centerIn: parent
        // renderStrategy: Canvas.Threaded
        property int visualizerStyle: root.visualizerStyle
        property bool circleMode: root.circleMode
        property real circleModeSize: root.circleModeSize
        property int barWidth: root.barWidth
        property int blockHeight: root.blockHeight
        property int blockSpacing: root.blockSpacing
        property int spacing: {
            if (Enum.isLineStyle(visualizerStyle)) {
                return Math.max(1, root.barGap);
            }
            return root.barGap;
        }
        property var peaks: root.peaks
        property real bass: root.bass
        property real beat: root.beat
        property bool reduced: root.reduced
        property bool byLevel: root.byLevel
        property bool spin: root.spin
        property real ribbonCurve: root.ribbonCurve
        property real ribbonFull: root.ribbonFull
        property int barCount: root.values.length
        property bool centeredBars: root.centeredBars
        property int waveMode: root.waveMode
        property bool roundedBars: root.roundedBars
        property var values: {
            if (root.debugMode) {
                let copy = root.values.slice();
                copy[0] = height;
                return copy;
            }
            return root.values;
        }
        property bool fillWave: root.fillWave
        property bool waveSimulateWaveform: root.waveSimulateWaveform
        property bool circleModeFill: root.circleModeFill
        property bool waveform: root.waveform

        property real radiusOffset: barWidth / 2
        property int gradientHeight: canvas.height
        property int gradientWidth: canvas.width

        function updateGradients() {
            if (!canvas.available) {
                return;
            }
            canvas.requestPaint();
        }
        onHeightChanged: updateGradients()
        onWidthChanged: updateGradients()

        property var barColorsCfg: root.barColorsCfg
        property list<color> colors: Utils.getColors(barColorsCfg, barCount, kirigamiColorItem.Kirigami.Theme[barColorsCfg.systemColor])
        property var gradient: {
            if (canvas.available) {
                return Utils.buildCanvasGradient(getContext("2d"), barColorsCfg.smoothGradient, colors, barColorsCfg.colorsOrientation, canvas.height, canvas.width, circleMode);
            }
            return null;
        }

        property var waveFillColorsCfg: root.waveFillColorsCfg
        property list<color> waveFillColors: Utils.getColors(waveFillColorsCfg, barCount, kirigamiColorItem2.Kirigami.Theme[waveFillColorsCfg.systemColor])
        property var waveFillGradient: {
            if (canvas.available) {
                return Utils.buildCanvasGradient(getContext("2d"), waveFillColorsCfg.smoothGradient, waveFillColors, waveFillColorsCfg.colorsOrientation, canvas.height, canvas.width, circleMode);
            }
            return null;
        }

        property var inactiveBlockColorsCfg: root.inactiveBlockColorsCfg
        property list<color> inactiveBlockColors: Utils.getColors(inactiveBlockColorsCfg, barCount, kirigamiColorItem.Kirigami.Theme[inactiveBlockColorsCfg.systemColor])
        property var inactiveBlockGradient: {
            if (canvas.available) {
                return Utils.buildCanvasGradient(getContext("2d"), inactiveBlockColorsCfg.smoothGradient, inactiveBlockColors, inactiveBlockColorsCfg.colorsOrientation, canvas.height, canvas.width, circleMode);
            }
            return null;
        }
        property bool drawInactiveBlocks: root.drawInactiveBlocks

        width: {
            if (visualizerStyle === Enum.VisualizerStyles.Wave && waveMode === Enum.WaveMode.Square) {
                return barCount * spacing;
            } else if (Enum.isLineStyle(visualizerStyle) && (visualizerStyle !== Enum.VisualizerStyles.Wave
                                                          || waveMode === Enum.WaveMode.Curve || waveMode === Enum.WaveMode.Triangle)) {
                return (barCount - 1) * spacing;
            }
            return barCount * barWidth + ((barCount - 1) * spacing);
        }
        height: parent.height
        property bool fixAlign: barWidth % 2 === 0 && centeredBars && visualizerStyle === Enum.VisualizerStyles.Wave && !root.fixVertical

        onValuesChanged: { if (root.slow) slowPaint.start(); else canvas.requestPaint() }
        Timer { id: slowPaint; interval: 500; onTriggered: canvas.requestPaint() }
        onVisualizerStyleChanged: canvas.requestPaint()
        onPeaksChanged: canvas.requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (fixAlign) {
                ctx.translate(0.0, 0.5);
            }
            if (root.fixVertical) {
                ctx.translate(0.0, -0.5);
            }
            switch (visualizerStyle) {
            case Enum.VisualizerStyles.Bars:
                if (circleMode) {
                    ctx.fillStyle = gradient;
                } else {
                    ctx.strokeStyle = gradient;
                }
                DrawCanvas.bars(ctx, canvas, circleMode);
                break;
            case Enum.VisualizerStyles.Wave:
                ctx.fillStyle = waveFillGradient;
                ctx.strokeStyle = gradient;
                DrawCanvas.wave(ctx, canvas, circleMode);
                break;
            case Enum.VisualizerStyles.Blocks:
                // fill is done per block
                DrawCanvas.blocks(ctx, canvas, circleMode);
                break;
            case Enum.VisualizerStyles.PeakBars: Styles.peakBars(ctx, canvas); break;
            case Enum.VisualizerStyles.LedMeter: Styles.ledMeter(ctx, canvas); break;
            case Enum.VisualizerStyles.Mountain: Styles.mountain(ctx, canvas); break;
            case Enum.VisualizerStyles.Scope: Styles.scope(ctx, canvas); break;
            case Enum.VisualizerStyles.PixelMatrix: Styles.pixelMatrix(ctx, canvas); break;
            case Enum.VisualizerStyles.FloatingDots: Styles.floatingDots(ctx, canvas); break;
            case Enum.VisualizerStyles.TechLine: Styles.techLine(ctx, canvas); break;
            case Enum.VisualizerStyles.RadialBurst: Styles.radialBurst(ctx, canvas); break;
            case Enum.VisualizerStyles.PulseOrb: Styles.pulseOrb(ctx, canvas); break;
            case Enum.VisualizerStyles.Ribbon: Styles.ribbon(ctx, canvas); break;
            case Enum.VisualizerStyles.Sparkles: Styles.sparkles(ctx, canvas); break;
            case Enum.VisualizerStyles.GravitySparks: Styles.gravitySparks(ctx, canvas); break;
            case Enum.VisualizerStyles.OrbitRing: Styles.orbitRing(ctx, canvas); break;
            case Enum.VisualizerStyles.StereoScope: Styles.stereoScope(ctx, canvas); break;
            case Enum.VisualizerStyles.CrtScope: Styles.crtScope(ctx, canvas); break;
            case Enum.VisualizerStyles.SilkRibbon: Styles.silkRibbon(ctx, canvas); break;
            default:
                ctx.fillStyle = waveFillGradient;
                ctx.strokeStyle = gradient;
                DrawCanvas.wave(ctx, canvas, circleMode);
                break;
            }
            if (fixAlign) {
                ctx.translate(0.0, -0.5);
            }
        }
    }

    Shape {
        id: shape
        visible: root.debugMode
        width: canvas.width
        height: canvas.height
        anchors.centerIn: parent
        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1
            strokeColor: "red"
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 8]
            startX: 0
            startY: shape.height
            PathLine {
                x: shape.width
                y: shape.height
            }
            PathLine {
                x: shape.width
                y: 0
            }
            PathLine {
                x: 0
                y: 0
            }
            PathLine {
                x: 0
                y: shape.height
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1
            strokeColor: "red"
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 8]
            startX: 0
            startY: shape.height / 2
            PathLine {
                x: shape.width
                y: shape.height / 2
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1
            strokeColor: "red"
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 8]
            startX: shape.width / 2
            startY: 0
            PathLine {
                x: shape.width / 2
                y: shape.height
            }
        }
    }
}
