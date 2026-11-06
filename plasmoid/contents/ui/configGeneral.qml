import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// The basics: what the widget shows, how big it is, when it hides
KCM.SimpleKCM {
    property alias cfg_showLyrics: showLyrics.checked
    property alias cfg_showVisualizer: showViz.checked
    property int cfg_sizeMode
    property int cfg_widthPx
    property int cfg_heightPx
    property alias cfg_showPanel: showPanel.checked
    property alias cfg_panelColor: panelColor.value
    property int cfg_panelRadius
    property alias cfg_hideWhenNothingPlaying: hideIdle.checked
    property int cfg_hideAfterSec
    property alias cfg_pauseOnFullScreenWindow: pauseFull.checked
    property alias cfg_pauseOnMaximizedWindow: pauseMax.checked

    property bool cfg_showLyricsDefault
    property bool cfg_showVisualizerDefault
    property int cfg_sizeModeDefault
    property int cfg_widthPxDefault
    property int cfg_heightPxDefault
    property bool cfg_showPanelDefault
    property string cfg_panelColorDefault
    property int cfg_panelRadiusDefault
    property bool cfg_hideWhenNothingPlayingDefault
    property int cfg_hideAfterSecDefault
    property bool cfg_pauseOnFullScreenWindowDefault
    property bool cfg_pauseOnMaximizedWindowDefault

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Show") }
        RowLayout {
            Kirigami.FormData.label: i18n("Show:")
            QQC2.CheckBox { id: showLyrics; text: i18n("Lyrics") }
            QQC2.CheckBox { id: showViz; text: i18n("Visualizer") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("The visualizer needs cava.") }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Size") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Size:")
            model: [i18n("Free (drag to resize)"), i18n("Fixed"), i18n("Full screen width")]
            currentIndex: cfg_sizeMode
            onActivated: cfg_sizeMode = currentIndex
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Width × height (px):")
            QQC2.SpinBox {
                enabled: cfg_sizeMode === 1
                from: 0; to: 7680; stepSize: 10; editable: true
                value: cfg_widthPx
                onValueModified: cfg_widthPx = value
            }
            QQC2.Label { text: "×" }
            QQC2.SpinBox {
                enabled: cfg_sizeMode !== 0
                from: 0; to: 4000; stepSize: 10; editable: true
                value: cfg_heightPx
                onValueModified: cfg_heightPx = value
            }
            Kirigami.ContextualHelpButton { toolTipText: i18n("0 means as small as possible.") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Background:")
            QQC2.CheckBox { id: showPanel }
            ColorField { id: panelColor; alpha: true; enabled: showPanel.checked }
            QQC2.Label { text: i18n("corners"); enabled: showPanel.checked }
            QQC2.SpinBox {
                enabled: showPanel.checked
                from: 0; to: 200
                value: cfg_panelRadius
                onValueModified: cfg_panelRadius = value
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Hide and pause") }
        QQC2.CheckBox { id: hideIdle; text: i18n("Hide when nothing is playing") }
        RowLayout {
            QQC2.CheckBox {
                text: i18n("Hide after pause or silence")
                checked: cfg_hideAfterSec > 0
                onToggled: cfg_hideAfterSec = checked ? 300 : 0
            }
            SecondsSpinBox {
                enabled: cfg_hideAfterSec > 0
                from: 100; to: 360000; stepSize: 500
                value: cfg_hideAfterSec * 100
                onValueModified: cfg_hideAfterSec = Math.max(1, Math.round(value / 100))
            }
            Kirigami.ContextualHelpButton { toolTipText: i18n("After the music has been paused this long, the widget fades out and the lyrics and the visualizer stop. The visualizer also hides after this long of silence. Playing again brings everything back.") }
        }
        RowLayout {
            QQC2.CheckBox { id: pauseFull; text: i18n("Stop while a window is full screen") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Saves power: no lyric updates, lookups or visualizer until the window closes.") }
        }
        RowLayout {
            QQC2.CheckBox { id: pauseMax; text: i18n("Hide while a window is maximized") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("The song and lyrics are still followed, so the widget fades back in on the right line when you are back on the desktop. The visualizer stops meanwhile.") }
        }
    }
}
