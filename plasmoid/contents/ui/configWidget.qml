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
    property bool cfg_hideWhenNothingPlayingDefault
    property int cfg_fadeWhenPausedMinDefault
    property bool cfg_pauseOnFullScreenWindowDefault
    property bool cfg_pauseOnMaximizedWindowDefault

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Size") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Size:")
            model: [i18n("Free (drag to resize)"), i18n("Fixed width and height"), i18n("Full screen width")]
            currentIndex: cfg_sizeMode
            onActivated: cfg_sizeMode = currentIndex
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Width (px):")
            enabled: cfg_sizeMode === 1
            from: 200; to: 7680; stepSize: 10; editable: true
            value: cfg_widthPx
            onValueModified: cfg_widthPx = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Height (px):")
            enabled: cfg_sizeMode !== 0
            from: 60; to: 4000; stepSize: 10; editable: true
            value: cfg_heightPx
            onValueModified: cfg_heightPx = value
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Full screen width uses the width of the screen the widget is on. Plasma places the widget; if it does not start at the left edge, drag it there once.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Background") }
        QQC2.CheckBox { id: showPanel; Kirigami.FormData.label: i18n("Panel:"); text: i18n("Show a background panel") }
        ColorField { id: panelColor; Kirigami.FormData.label: i18n("Color:"); enabled: showPanel.checked }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Corner radius:")
            from: 0; to: 60
            enabled: showPanel.checked
            value: cfg_panelRadius
            onValueModified: cfg_panelRadius = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Visibility") }
        QQC2.CheckBox { id: hideIdle; Kirigami.FormData.label: i18n("When idle:"); text: i18n("Hide the widget when nothing is playing") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Fade out when paused:")
            from: 0; to: 120
            textFromValue: function(v) { return v === 0 ? i18n("never") : i18n("after %1 min", v) }
            value: cfg_fadeWhenPausedMin
            onValueModified: cfg_fadeWhenPausedMin = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Power saving") }
        QQC2.CheckBox { id: pauseFull; Kirigami.FormData.label: i18n("Pause everything when:"); text: i18n("A window is full screen") }
        QQC2.CheckBox { id: pauseMax; text: i18n("A window is maximized") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("While paused the widget does no work at all: no audio analysis, no lyric timing or animation, no lookups or look-ahead. It picks up again, on the right line, when the window closes or leaves full screen. Only windows on the same screen count.")
        }
    }
}
