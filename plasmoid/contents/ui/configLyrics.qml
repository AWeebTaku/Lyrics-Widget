import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import QtQuick.Layouts

KCM.SimpleKCM {
    property alias cfg_fontFamily: fontField.value
    property int cfg_mainSize
    property int cfg_sideSize
    property alias cfg_boldCurrent: boldCurrent.checked
    property alias cfg_textColor: textColor.value
    property alias cfg_dimColor: dimColor.value
    property alias cfg_showRoman: showRoman.checked
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showNeighbours: showNeighbours.checked
    property alias cfg_animateLines: animate.checked
    property alias cfg_karaoke: karaoke.checked
    property alias cfg_tintFromArt: tint.checked
    property alias cfg_tintVisualizer: tintViz.checked
    property alias cfg_autoCompact: compact.checked
    property alias cfg_audioListen: listen.checked
    property alias cfg_audioSync: aSync.checked
    property alias cfg_audioTempo: aTempo.checked
    property alias cfg_beatPulse: pulse.checked
    property int cfg_offsetMs
    property alias cfg_showSyncControls: showSync.checked

    // Plasma looks for the *Default twins too
    property string cfg_fontFamilyDefault
    property int cfg_mainSizeDefault
    property int cfg_sideSizeDefault
    property bool cfg_boldCurrentDefault
    property string cfg_textColorDefault
    property string cfg_dimColorDefault
    property bool cfg_showRomanDefault
    property bool cfg_showHeaderDefault
    property bool cfg_showNeighboursDefault
    property bool cfg_animateLinesDefault
    property bool cfg_karaokeDefault
    property bool cfg_tintFromArtDefault
    property bool cfg_tintVisualizerDefault
    property bool cfg_autoCompactDefault
    property bool cfg_audioListenDefault
    property bool cfg_audioSyncDefault
    property bool cfg_audioTempoDefault
    property bool cfg_beatPulseDefault
    property int cfg_offsetMsDefault
    property bool cfg_showSyncControlsDefault

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Text") }
        FontField { id: fontField; Kirigami.FormData.label: i18n("Font:") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Current line size:")
            from: 12; to: 120
            value: cfg_mainSize
            onValueModified: cfg_mainSize = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Neighbour line size:")
            from: 8; to: 80
            value: cfg_sideSize
            onValueModified: cfg_sideSize = value
        }
        QQC2.CheckBox { id: boldCurrent; Kirigami.FormData.label: i18n("Style:"); text: i18n("Bold current line") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Colors") }
        ColorField { id: textColor; Kirigami.FormData.label: i18n("Current line:") }
        ColorField { id: dimColor; Kirigami.FormData.label: i18n("Other lines:") }
        QQC2.CheckBox { id: tint; Kirigami.FormData.label: i18n("Album art:"); text: i18n("Color the current line from the cover") }
        QQC2.CheckBox { id: tintViz; text: i18n("Color the visualizer from the cover too"); enabled: tint.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Content") }
        QQC2.CheckBox { id: showRoman; Kirigami.FormData.label: i18n("Romanization:"); text: i18n("Replace the original with romanization when available") }
        QQC2.CheckBox { id: showNeighbours; Kirigami.FormData.label: i18n("Lines:"); text: i18n("Show the previous and next lines") }
        QQC2.CheckBox { id: animate; Kirigami.FormData.label: i18n("Animation:"); text: i18n("Swipe up and fade in on each new line") }
        QQC2.CheckBox { id: karaoke; Kirigami.FormData.label: i18n("Karaoke:"); text: i18n("Highlight each word as it is sung (when the lyrics have word timing)") }
        QQC2.CheckBox { id: compact; Kirigami.FormData.label: i18n("Small widget:"); text: i18n("Hide the previous/next lines automatically when there is no room") }
        QQC2.CheckBox { id: showHeader; Kirigami.FormData.label: i18n("Header:"); text: i18n("Show artist — title") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Timing") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Sync offset (ms):")
            from: -5000; to: 5000; stepSize: 50; editable: true
            value: cfg_offsetMs
            onValueModified: cfg_offsetMs = value
        }
        QQC2.CheckBox {
            id: showSync
            Kirigami.FormData.label: i18n("Per-song sync:")
            text: i18n("Show the +/- sync buttons when hovering the widget")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("The offset above applies to every song. The hover buttons adjust one song and are remembered for it; they also enable a hint in the header when the matched lyrics version is a different length.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Listen to the audio") }
        QQC2.CheckBox { id: listen; Kirigami.FormData.label: i18n("Listening:"); text: i18n("Listen to what the computer is playing") }
        QQC2.CheckBox { id: aSync; text: i18n("Check the lyric timing against the singing (experimental)"); enabled: listen.checked }
        QQC2.CheckBox { id: aTempo; text: i18n("Match the line animation to the tempo"); enabled: listen.checked }
        QQC2.CheckBox { id: pulse; text: i18n("Pulse the current line to the beat"); enabled: listen.checked }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Reads the sound going to your speakers (never the microphone) through PipeWire/PulseAudio, only while music plays and the widget is visible. Only a few numbers per second (loudness and beats) are kept; nothing is recorded or sent anywhere. It hears everything that plays, not only the music player. Timing checks need a clear voice and about a minute of the song, and only change songs you haven't adjusted by hand.")
        }
    }
}
