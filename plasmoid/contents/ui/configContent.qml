import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "audioviz"

// What the widget shows and when: the lyrics (what to show, timing, buttons) and the visualizer's audio input
KCM.SimpleKCM {
    id: page
    property alias cfg_showRoman: showRoman.checked
    property alias cfg_showNeighbours: showNeighbours.checked
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_animateLines: animate.checked
    property int cfg_offsetMs
    property alias cfg_showSyncControls: showSync.checked
    property alias cfg_hoverButtons: hoverButtons.checked
    property alias cfg_barCount: cava.cfg_barCount
    property alias cfg_framerate: cava.cfg_framerate
    property alias cfg_autoSensitivity: cava.cfg_autoSensitivity
    property alias cfg_sensitivityEnabled: cava.cfg_sensitivityEnabled
    property alias cfg_sensitivity: cava.cfg_sensitivity
    property alias cfg_lowerCutoffFreq: cava.cfg_lowerCutoffFreq
    property alias cfg_higherCutoffFreq: cava.cfg_higherCutoffFreq
    property alias cfg_cavaSleepTimer: cava.cfg_cavaSleepTimer
    property alias cfg_noiseReduction: cava.cfg_noiseReduction
    property alias cfg_monstercat: cava.cfg_monstercat
    property alias cfg_waves: cava.cfg_waves
    property alias cfg_inputMethod: cava.cfg_inputMethod
    property alias cfg_inputSource: cava.cfg_inputSource
    property alias cfg_sampleRate: cava.cfg_sampleRate
    property alias cfg_sampleBits: cava.cfg_sampleBits
    property alias cfg_inputChannels: cava.cfg_inputChannels
    property alias cfg_autoconnect: cava.cfg_autoconnect
    property alias cfg_active: cava.cfg_active
    property alias cfg_remix: cava.cfg_remix
    property alias cfg_virtual: cava.cfg_virtual
    property alias cfg_outputChannels: cava.cfg_outputChannels
    property alias cfg_monoOption: cava.cfg_monoOption
    property alias cfg_reverse: cava.cfg_reverse
    property alias cfg_waveform: cava.cfg_waveform
    property alias cfg_eqEnabled: cava.cfg_eqEnabled
    property alias cfg_eq: cava.cfg_eq

    // Plasma looks for the *Default twins too
    property bool cfg_showRomanDefault
    property bool cfg_showNeighboursDefault
    property bool cfg_showHeaderDefault
    property bool cfg_animateLinesDefault
    property int cfg_offsetMsDefault
    property bool cfg_showSyncControlsDefault
    property bool cfg_hoverButtonsDefault

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
                Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Lines") }
                QQC2.CheckBox { id: showRoman; text: i18n("Romanized text (Japanese, Korean, Chinese)") }
                QQC2.CheckBox { id: showNeighbours; text: i18n("Previous and next lines") }
                QQC2.CheckBox { id: showHeader; text: i18n("Artist and title") }
                QQC2.CheckBox { id: animate; text: i18n("Animate line changes") }

                Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Timing") }
                RowLayout {
                    Kirigami.FormData.label: i18n("Shift all lyrics (ms):")
                    QQC2.SpinBox {
                        from: -5000; to: 5000; stepSize: 50; editable: true
                        value: cfg_offsetMs
                        onValueModified: cfg_offsetMs = value
                    }
                    Kirigami.ContextualHelpButton { toolTipText: i18n("Positive: lyrics appear earlier. Negative: later.") }
                }

                Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Hover buttons") }
                QQC2.CheckBox { id: showSync; text: i18n("Sync: nudge this song's timing") }
                RowLayout {
                    QQC2.CheckBox { id: hoverButtons; text: i18n("Corner: other lyrics and library") }
                    Kirigami.ContextualHelpButton { toolTipText: i18n("Top right corner. The arrows look for other lyrics for the song and keep the one they find in your library. The pencil opens the lyrics library.") }
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
                ConfigCava {
                    id: cava
                    Layout.fillWidth: true
                    enabled: (Plasmoid.configuration?.showVisualizer ?? true)
                }
            }
        }
    }
}
