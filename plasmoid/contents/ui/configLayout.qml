import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Everything about where things go and when they show: widget size and background, where the lyrics and
// the visualizer sit, and when the widget hides or rests.
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
    property alias cfg_hideWhenIdle: hideWhenIdleCheckbox.checked
    property alias cfg_idleTimer: idleTimerSpinbox.value
    property alias cfg_debugMode: debugModeCheckbox.checked
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
    property int cfg_idleTimerDefault
    property bool cfg_debugModeDefault
    property bool cfg_hideWhenNothingPlayingDefault
    property int cfg_fadeWhenPausedMinDefault
    property bool cfg_pauseOnFullScreenWindowDefault
    property bool cfg_pauseOnMaximizedWindowDefault

    Kirigami.FormLayout {
        // ---- widget
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Widget") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Size:")
            model: [i18n("Free (drag to resize)"), i18n("Fixed width and height"), i18n("Full screen width")]
            currentIndex: cfg_sizeMode
            onActivated: cfg_sizeMode = currentIndex
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Width × height (px):")
            enabled: cfg_sizeMode !== 0
            QQC2.SpinBox {
                enabled: cfg_sizeMode === 1
                from: 0; to: 7680; stepSize: 10; editable: true
                value: cfg_widthPx
                onValueModified: cfg_widthPx = value
            }
            QQC2.Label { text: "×" }
            QQC2.SpinBox {
                from: 0; to: 4000; stepSize: 10; editable: true
                value: cfg_heightPx
                onValueModified: cfg_heightPx = value
            }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("0 makes it as small as possible. Full screen width uses the width of the screen the widget is on; the height still applies. Plasma places the widget: drag it to the left edge once if needed.")
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Background:")
            QQC2.CheckBox { id: showPanel; text: i18n("Panel") }
            ColorField { id: panelColor; enabled: showPanel.checked }
            QQC2.Label { text: i18n("Corner radius") }
            QQC2.SpinBox {
                enabled: showPanel.checked
                from: 0; to: 200
                value: cfg_panelRadius
                onValueModified: cfg_panelRadius = value
            }
        }

        // ---- lyrics position
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Lyrics position") }
        RowLayout {
            Kirigami.FormData.label: i18n("Place in the widget:")
            AlignGrid { h: cfg_lyricsHAlign; v: cfg_lyricsVAlign; onPicked: (hh, vv) => { cfg_lyricsHAlign = hh; cfg_lyricsVAlign = vv } }
            ColumnLayout {
                RowLayout {
                    QQC2.Label { text: i18n("Shift right") }
                    QQC2.SpinBox { from: -4000; to: 4000; stepSize: 5; editable: true; value: cfg_lyricsOffsetX; onValueModified: cfg_lyricsOffsetX = value }
                }
                RowLayout {
                    QQC2.Label { text: i18n("Shift down") }
                    QQC2.SpinBox { from: -4000; to: 4000; stepSize: 5; editable: true; value: cfg_lyricsOffsetY; onValueModified: cfg_lyricsOffsetY = value }
                }
            }
        }

        // ---- visualizer
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Audio visualizer") }
        QQC2.CheckBox {
            id: showViz
            Kirigami.FormData.label: i18n("Visualizer:")
            text: i18n("Show it (needs cava; runs only while music plays)")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Size (% of widget):")
            enabled: showViz.checked
            QQC2.SpinBox { from: 0; to: 100; value: cfg_vizWidthPct; onValueModified: cfg_vizWidthPct = value }
            QQC2.Label { text: i18n("wide") }
            QQC2.SpinBox { from: 0; to: 100; value: cfg_vizHeightPct; onValueModified: cfg_vizHeightPct = value }
            QQC2.Label { text: i18n("high") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Place in the widget:")
            enabled: showViz.checked
            AlignGrid { h: cfg_vizHAlign; v: cfg_vizVAlign; onPicked: (hh, vv) => { cfg_vizHAlign = hh; cfg_vizVAlign = vv } }
            ColumnLayout {
                RowLayout {
                    QQC2.Label { text: i18n("Shift right") }
                    QQC2.SpinBox { from: -4000; to: 4000; stepSize: 5; editable: true; value: cfg_vizOffsetX; onValueModified: cfg_vizOffsetX = value }
                }
                RowLayout {
                    QQC2.Label { text: i18n("Shift down") }
                    QQC2.SpinBox { from: -4000; to: 4000; stepSize: 5; editable: true; value: cfg_vizOffsetY; onValueModified: cfg_vizOffsetY = value }
                }
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Auto-hide when silent:")
            enabled: showViz.checked
            QQC2.CheckBox { id: hideWhenIdleCheckbox }
            QQC2.Label { text: i18n("after") }
            QQC2.SpinBox { id: idleTimerSpinbox; enabled: hideWhenIdleCheckbox.checked; from: 1; to: 60 }
            QQC2.Label { text: i18n("seconds") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Debug mode:")
            enabled: showViz.checked
            QQC2.CheckBox { id: debugModeCheckbox }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Print additional messages to the system log, force full height on the first bar and draw a grid, to spot sizing issues. Style, colours and audio input are on the Visualizer style and Audio input pages (shown while the visualizer is on).")
            }
        }

        // ---- visibility and power
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Visibility and power") }
        QQC2.CheckBox { id: hideIdle; Kirigami.FormData.label: i18n("When idle:"); text: i18n("Hide the widget when nothing is playing") }
        RowLayout {
            Kirigami.FormData.label: i18n("Fade out when paused:")
            QQC2.SpinBox {
                from: 0; to: 120
                textFromValue: function(v) { return v === 0 ? i18n("never") : i18n("after %1 min", v) }
                value: cfg_fadeWhenPausedMin
                onValueModified: cfg_fadeWhenPausedMin = value
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Pause everything when a window is:")
            QQC2.CheckBox { id: pauseFull; text: i18n("full screen") }
            QQC2.CheckBox { id: pauseMax; text: i18n("maximized") }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("While paused the widget does no work at all: no audio analysis, no lyric timing or animation, no lookups or look-ahead. It picks up again, on the right line, when the window closes. Only windows on the same screen count.")
            }
        }
    }
}
