import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showVisualizer: show.checked
    property int cfg_vizHeightPct
    property alias cfg_hideWhenIdle: hideWhenIdleCheckbox.checked
    property alias cfg_idleTimer: idleTimerSpinbox.value
    property alias cfg_debugMode: debugModeCheckbox.checked
    property bool cfg_showVisualizerDefault
    property int cfg_vizHeightPctDefault
    property bool cfg_hideWhenIdleDefault
    property int cfg_idleTimerDefault
    property bool cfg_debugModeDefault

    Kirigami.FormLayout {
        QQC2.CheckBox { id: show; Kirigami.FormData.label: i18n("Audio visualizer:"); text: i18n("Show behind the lyrics") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Height (% of widget):")
            enabled: show.checked
            from: 10; to: 100
            value: cfg_vizHeightPct
            onValueModified: cfg_vizHeightPct = value
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Auto-hide when silent:")
            enabled: show.checked
            QQC2.CheckBox { id: hideWhenIdleCheckbox }
            QQC2.Label { text: i18n("After") }
            QQC2.SpinBox {
                id: idleTimerSpinbox
                enabled: hideWhenIdleCheckbox.checked
                from: 1; to: 60
            }
            QQC2.Label { text: i18n("seconds") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Debug mode:")
            enabled: show.checked
            QQC2.CheckBox { id: debugModeCheckbox }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Print additional messages to the system log. To make it easier to spot sizing issues, this will also force full height to the first visualizer bar and displays a grid over it.")
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Needs cava (sudo pacman -S cava). It only runs while music is playing.\n\nMore options on the other Visualizer pages:\n• Visualizer style: bars, blocks, wave or circle; colors, gradients, shape\n• Audio input (CAVA): input source, smoothing, sensitivity, equalizer, frame rate, pause on fullscreen or maximized windows")
        }
    }
}
