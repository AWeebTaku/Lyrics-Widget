import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property int cfg_sizeMode
    property int cfg_widthPx
    property int cfg_heightPx
    property alias cfg_showPanel: showPanel.checked
    property alias cfg_panelColor: panelColor.value
    property int cfg_panelRadius
    property int cfg_lyricsHAlign
    property int cfg_lyricsVAlign
    property int cfg_lyricsOffsetX
    property int cfg_lyricsOffsetY
    property alias cfg_showVisualizer: showViz.checked
    property int cfg_vizWidthPct
    property int cfg_vizHeightPct
    property int cfg_vizHAlign
    property int cfg_vizVAlign
    property int cfg_vizOffsetX
    property int cfg_vizOffsetY
    property alias cfg_hideWhenIdle: hideSilent.checked
    property alias cfg_hideWhenNothingPlaying: hideIdle.checked
    property int cfg_fadeWhenPausedMin
    property alias cfg_pauseOnFullScreenWindow: pauseFull.checked
    property alias cfg_pauseOnMaximizedWindow: pauseMax.checked

    property int cfg_sizeModeDefault
    property int cfg_widthPxDefault
    property int cfg_heightPxDefault
    property bool cfg_showPanelDefault
    property string cfg_panelColorDefault
    property int cfg_panelRadiusDefault
    property int cfg_lyricsHAlignDefault
    property int cfg_lyricsVAlignDefault
    property int cfg_lyricsOffsetXDefault
    property int cfg_lyricsOffsetYDefault
    property bool cfg_showVisualizerDefault
    property int cfg_vizWidthPctDefault
    property int cfg_vizHeightPctDefault
    property int cfg_vizHAlignDefault
    property int cfg_vizVAlignDefault
    property int cfg_vizOffsetXDefault
    property int cfg_vizOffsetYDefault
    property bool cfg_hideWhenIdleDefault
    property bool cfg_hideWhenNothingPlayingDefault
    property int cfg_fadeWhenPausedMinDefault
    property bool cfg_pauseOnFullScreenWindowDefault
    property bool cfg_pauseOnMaximizedWindowDefault

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Widget") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Size:")
            model: [i18n("Free (drag to resize)"), i18n("Fixed"), i18n("Full screen width")]
            currentIndex: cfg_sizeMode
            onActivated: cfg_sizeMode = currentIndex
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Width (px):")
            enabled: cfg_sizeMode === 1
            from: 0; to: 7680; stepSize: 10; editable: true
            value: cfg_widthPx
            onValueModified: cfg_widthPx = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Height (px):")
            enabled: cfg_sizeMode !== 0
            from: 0; to: 4000; stepSize: 10; editable: true
            value: cfg_heightPx
            onValueModified: cfg_heightPx = value
        }
        QQC2.CheckBox { id: showPanel; text: i18n("Show background") }
        ColorField { id: panelColor; Kirigami.FormData.label: i18n("Background color:"); enabled: showPanel.checked }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Rounded corners (px):")
            enabled: showPanel.checked
            from: 0; to: 200
            value: cfg_panelRadius
            onValueModified: cfg_panelRadius = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Lyrics") }
        AlignGrid {
            Kirigami.FormData.label: i18n("Position:")
            h: cfg_lyricsHAlign; v: cfg_lyricsVAlign
            onPicked: (hh, vv) => { cfg_lyricsHAlign = hh; cfg_lyricsVAlign = vv }
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Move right (px):")
            from: -4000; to: 4000; stepSize: 5; editable: true
            value: cfg_lyricsOffsetX
            onValueModified: cfg_lyricsOffsetX = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Move down (px):")
            from: -4000; to: 4000; stepSize: 5; editable: true
            value: cfg_lyricsOffsetY
            onValueModified: cfg_lyricsOffsetY = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Visualizer") }
        RowLayout {
            QQC2.CheckBox { id: showViz; text: i18n("Show visualizer") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Needs cava. More options are on the Visualizer style and Audio input pages.") }
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Width (%):")
            enabled: showViz.checked
            from: 0; to: 100
            value: cfg_vizWidthPct
            onValueModified: cfg_vizWidthPct = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Height (%):")
            enabled: showViz.checked
            from: 0; to: 100
            value: cfg_vizHeightPct
            onValueModified: cfg_vizHeightPct = value
        }
        AlignGrid {
            Kirigami.FormData.label: i18n("Position:")
            enabled: showViz.checked
            h: cfg_vizHAlign; v: cfg_vizVAlign
            onPicked: (hh, vv) => { cfg_vizHAlign = hh; cfg_vizVAlign = vv }
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Move right (px):")
            enabled: showViz.checked
            from: -4000; to: 4000; stepSize: 5; editable: true
            value: cfg_vizOffsetX
            onValueModified: cfg_vizOffsetX = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Move down (px):")
            enabled: showViz.checked
            from: -4000; to: 4000; stepSize: 5; editable: true
            value: cfg_vizOffsetY
            onValueModified: cfg_vizOffsetY = value
        }
        QQC2.CheckBox { id: hideSilent; enabled: showViz.checked; text: i18n("Hide when the music is silent") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Hide and pause") }
        QQC2.CheckBox { id: hideIdle; text: i18n("Hide when nothing is playing") }
        QQC2.CheckBox {
            text: i18n("Fade out after 5 minutes of pause")
            checked: cfg_fadeWhenPausedMin > 0
            onToggled: cfg_fadeWhenPausedMin = checked ? 5 : 0
        }
        RowLayout {
            QQC2.CheckBox { id: pauseFull; text: i18n("Stop working while a window is full screen") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Saves power: no lyric updates, lookups or visualizer until the window closes.") }
        }
        QQC2.CheckBox { id: pauseMax; text: i18n("Stop working while a window is maximized") }
    }
}
