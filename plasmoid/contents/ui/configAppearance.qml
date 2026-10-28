import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "audioviz"

// How things look: the lyric text (font, style, colours) and the visualizer (the Plasma Audio Visualizer's style page)
KCM.SimpleKCM {
    id: page
    property alias cfg_fontFamily: fontField.value
    property int cfg_mainSize
    property int cfg_sideSize
    property int cfg_currentWeight
    property int cfg_sideWeight
    property alias cfg_fontItalic: italic.checked
    property alias cfg_fontUnderline: underline.checked
    property int cfg_letterSpacing
    property int cfg_fontCaps
    property alias cfg_shadowOn: shadowOn.checked
    property alias cfg_shadowColor: shadowColor.value
    property int cfg_shadowX
    property int cfg_shadowY
    property int cfg_shadowBlur
    property alias cfg_outlineOn: outlineOn.checked
    property alias cfg_outlineColor: outlineColor.value
    property int cfg_outlineWidth
    property alias cfg_highlightOn: highlightOn.checked
    property alias cfg_highlightColor: highlightColor.value
    property int cfg_highlightPadX
    property int cfg_highlightPadY
    property int cfg_highlightRadius
    property alias cfg_textColor: textColor.value
    property alias cfg_dimColor: dimColor.value
    property alias cfg_tintFromArt: tint.checked
    property alias cfg_liftDark: liftDark.checked
    property int cfg_tintMode
    property int cfg_lyricColorFlow
    property int cfg_vizColorFlow
    property alias cfg_barGap: viz.cfg_barGap
    property alias cfg_barWidth: viz.cfg_barWidth
    property alias cfg_blockHeight: viz.cfg_blockHeight
    property alias cfg_blockSpacing: viz.cfg_blockSpacing
    property alias cfg_centeredBars: viz.cfg_centeredBars
    property alias cfg_waveSimulateWaveform: viz.cfg_waveSimulateWaveform
    property alias cfg_roundedBars: viz.cfg_roundedBars
    property alias cfg_fillPanel: viz.cfg_fillPanel
    property alias cfg_visualizerStyle: viz.cfg_visualizerStyle
    property alias cfg_waveMode: viz.cfg_waveMode
    property alias cfg_pinnedDownSides: viz.cfg_pinnedDownSides
    property alias cfg_circleMode: viz.cfg_circleMode
    property alias cfg_circleModeFill: viz.cfg_circleModeFill
    property alias cfg_circleModeSize: viz.cfg_circleModeSize
    property alias cfg_barColors: viz.cfg_barColors
    property alias cfg_waveFillColors: viz.cfg_waveFillColors
    property alias cfg_inactiveBlockColors: viz.cfg_inactiveBlockColors
    property alias cfg_drawInactiveBlocks: viz.cfg_drawInactiveBlocks
    property alias cfg_fillWave: viz.cfg_fillWave
    property alias cfg_expanding: viz.cfg_expanding
    property alias cfg_length: viz.cfg_length
    property alias cfg_minimumLength: viz.cfg_minimumLength
    property alias cfg_orientation: viz.cfg_orientation

    // Plasma looks for the *Default twins too
    property string cfg_fontFamilyDefault
    property int cfg_mainSizeDefault
    property int cfg_sideSizeDefault
    property int cfg_currentWeightDefault
    property int cfg_sideWeightDefault
    property bool cfg_fontItalicDefault
    property bool cfg_fontUnderlineDefault
    property int cfg_letterSpacingDefault
    property int cfg_fontCapsDefault
    property bool cfg_shadowOnDefault
    property string cfg_shadowColorDefault
    property int cfg_shadowXDefault
    property int cfg_shadowYDefault
    property int cfg_shadowBlurDefault
    property bool cfg_outlineOnDefault
    property string cfg_outlineColorDefault
    property int cfg_outlineWidthDefault
    property bool cfg_highlightOnDefault
    property string cfg_highlightColorDefault
    property int cfg_highlightPadXDefault
    property int cfg_highlightPadYDefault
    property int cfg_highlightRadiusDefault
    property string cfg_textColorDefault
    property string cfg_dimColorDefault
    property bool cfg_tintFromArtDefault
    property bool cfg_liftDarkDefault
    property int cfg_tintModeDefault
    property int cfg_lyricColorFlowDefault
    property int cfg_vizColorFlowDefault

    function weightIndex(w) {
        for (let i = 0; i < weights.length; ++i)
            if (weights[i].value === w)
                return i
        return 1
    }
    readonly property var weights: [
        { text: i18n("Light"), value: 300 }, { text: i18n("Normal"), value: 400 }, { text: i18n("Medium"), value: 500 },
        { text: i18n("Semi-bold"), value: 600 }, { text: i18n("Bold"), value: 700 }, { text: i18n("Black"), value: 900 }
    ]

    ColumnLayout {
        QQC2.TabBar {
            id: tabs
            Layout.fillWidth: true
            implicitWidth: 0 // the width comes from the layout; the buttons take half each
            QQC2.TabButton { text: i18n("Lyrics"); width: tabs.width / 2 }
            QQC2.TabButton { text: i18n("Visualizer"); width: tabs.width / 2 }
        }
        StackLayout {
            currentIndex: tabs.currentIndex
            Layout.fillWidth: true
        Kirigami.FormLayout {
            Layout.fillWidth: true
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Text") }
            FontField { id: fontField; Kirigami.FormData.label: i18n("Font:") }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Current line size:")
                from: 0; to: 300
                value: cfg_mainSize
                onValueModified: cfg_mainSize = value
            }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Other lines size:")
                from: 0; to: 300
                value: cfg_sideSize
                onValueModified: cfg_sideSize = value
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Current line weight:")
                textRole: "text"; valueRole: "value"
                model: weights
                currentIndex: weightIndex(cfg_currentWeight)
                onActivated: cfg_currentWeight = currentValue
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Other lines weight:")
                textRole: "text"; valueRole: "value"
                model: weights
                currentIndex: weightIndex(cfg_sideWeight)
                onActivated: cfg_sideWeight = currentValue
            }
            QQC2.CheckBox { id: italic; text: i18n("Italic") }
            QQC2.CheckBox { id: underline; text: i18n("Underline") }
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Letters:")
                model: [i18n("As written"), i18n("UPPERCASE"), i18n("lowercase"), i18n("Small caps")]
                currentIndex: cfg_fontCaps
                onActivated: cfg_fontCaps = currentIndex
            }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Letter spacing (px):")
                from: -5; to: 30
                value: cfg_letterSpacing
                onValueModified: cfg_letterSpacing = value
            }

            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Effects") }
            QQC2.CheckBox { id: shadowOn; text: i18n("Shadow") }
            ColorField { id: shadowColor; alpha: true; Kirigami.FormData.label: i18n("Shadow color:"); enabled: shadowOn.checked }
            RowLayout {
                Kirigami.FormData.label: i18n("Shadow offset (px):")
                enabled: shadowOn.checked
                QQC2.SpinBox { from: -30; to: 30; value: cfg_shadowX; onValueModified: cfg_shadowX = value }
                QQC2.Label { text: "×" }
                QQC2.SpinBox { from: -30; to: 30; value: cfg_shadowY; onValueModified: cfg_shadowY = value }
            }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Shadow blur:")
                enabled: shadowOn.checked
                from: 0; to: 30
                value: cfg_shadowBlur
                onValueModified: cfg_shadowBlur = value
            }
            QQC2.CheckBox { id: outlineOn; text: i18n("Outline") }
            ColorField { id: outlineColor; Kirigami.FormData.label: i18n("Outline color:"); enabled: outlineOn.checked }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Outline width (px):")
                enabled: outlineOn.checked
                from: 1; to: 6
                value: cfg_outlineWidth
                onValueModified: cfg_outlineWidth = value
            }
            QQC2.CheckBox { id: highlightOn; text: i18n("Highlight bar behind the current line") }
            ColorField { id: highlightColor; alpha: true; Kirigami.FormData.label: i18n("Highlight color:"); enabled: highlightOn.checked }
            RowLayout {
                Kirigami.FormData.label: i18n("Highlight padding (px):")
                enabled: highlightOn.checked
                QQC2.SpinBox { from: 0; to: 100; value: cfg_highlightPadX; onValueModified: cfg_highlightPadX = value }
                QQC2.Label { text: "×" }
                QQC2.SpinBox { from: 0; to: 100; value: cfg_highlightPadY; onValueModified: cfg_highlightPadY = value }
            }
            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Highlight corners (px):")
                enabled: highlightOn.checked
                from: 0; to: 100
                value: cfg_highlightRadius
                onValueModified: cfg_highlightRadius = value
            }

            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Colors") }
            ColorField { id: textColor; Kirigami.FormData.label: i18n("Current line:") }
            ColorField { id: dimColor; alpha: true; Kirigami.FormData.label: i18n("Other lines:") }
            QQC2.CheckBox { id: tint; text: i18n("Use colors from the album cover") }
            RowLayout {
                enabled: tint.checked
                QQC2.CheckBox { id: liftDark; text: i18n("Lighten very dark cover colors") }
                Kirigami.ContextualHelpButton { toolTipText: i18n("A nearly black cover would make the lyrics vanish on a dark desktop. Colors darker than half brightness are raised to it.") }
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Cover colors:")
                enabled: tint.checked
                model: [i18n("Multiple colors"), i18n("One color")]
                currentIndex: cfg_tintMode
                onActivated: cfg_tintMode = currentIndex
            }
            ColorFlowBox {
                Kirigami.FormData.label: i18n("Lyrics color flow:")
                enabled: tint.checked && cfg_tintMode === 0
                value: cfg_lyricColorFlow
                onPicked: v => cfg_lyricColorFlow = v
            }
            ColorFlowBox {
                Kirigami.FormData.label: i18n("Visualizer color flow:")
                enabled: tint.checked && cfg_tintMode === 0
                value: cfg_vizColorFlow
                onPicked: v => cfg_vizColorFlow = v
            }
        }
            ColumnLayout {
                QQC2.Label {
                    visible: !(Plasmoid.configuration?.showVisualizer ?? true)
                    text: i18n("The visualizer is off (General page). These settings apply once it is on.")
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                ConfigVisualizer {
                    id: viz
                    Layout.fillWidth: true
                    enabled: (Plasmoid.configuration?.showVisualizer ?? true)
                    cfg_tintFromArt: tint.checked
                    cfg_tintMode: page.cfg_tintMode
                }
            }
        }
    }
}
