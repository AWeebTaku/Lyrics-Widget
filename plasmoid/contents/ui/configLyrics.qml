import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import QtQuick.Layouts

KCM.SimpleKCM {
    property alias cfg_showLyrics: showLyrics.checked
    property alias cfg_fontFamily: fontField.value
    property int cfg_mainSize
    property int cfg_sideSize
    property alias cfg_boldCurrent: boldCurrent.checked
    property alias cfg_textColor: textColor.value
    property alias cfg_dimColor: dimColor.value
    property alias cfg_tintFromArt: tint.checked
    property int cfg_tintMode
    property alias cfg_showRoman: showRoman.checked
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_showNeighbours: showNeighbours.checked
    property alias cfg_animateLines: animate.checked
    property alias cfg_karaoke: karaoke.checked
    property alias cfg_showHeader: showHeader.checked
    property alias cfg_animateLines: animate.checked
    property int cfg_offsetMs
    property alias cfg_showSyncControls: showSync.checked

    // Plasma looks for the *Default twins too
    property bool cfg_showLyricsDefault
    property string cfg_fontFamilyDefault
    property int cfg_mainSizeDefault
    property int cfg_sideSizeDefault
    property bool cfg_boldCurrentDefault
    property string cfg_textColorDefault
    property string cfg_dimColorDefault
    property bool cfg_tintFromArtDefault
    property int cfg_tintModeDefault
    property bool cfg_showRomanDefault
    property bool cfg_showHeaderDefault
    property bool cfg_showNeighboursDefault
    property bool cfg_animateLinesDefault
    property bool cfg_karaokeDefault
    property bool cfg_showHeaderDefault
    property bool cfg_animateLinesDefault
    property int cfg_offsetMsDefault
    property bool cfg_showSyncControlsDefault

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLyrics
            Kirigami.FormData.label: i18n("Lyrics:")
            text: i18n("Show lyrics (off: no lookups at all, e.g. for a visualizer-only widget)")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Text") }
        FontField { id: fontField; Kirigami.FormData.label: i18n("Font:") }
        RowLayout {
            Kirigami.FormData.label: i18n("Size (px):")
            enabled: showLyrics.checked
            QQC2.SpinBox { from: 0; to: 300; value: cfg_mainSize; onValueModified: cfg_mainSize = value }
            QQC2.Label { text: i18n("current") }
            QQC2.SpinBox { from: 0; to: 300; value: cfg_sideSize; onValueModified: cfg_sideSize = value }
            QQC2.Label { text: i18n("others") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("0 hides that text.") }
        }
        QQC2.CheckBox { id: boldCurrent; Kirigami.FormData.label: i18n("Style:"); text: i18n("Bold current line") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Colors") }
        ColorField { id: textColor; Kirigami.FormData.label: i18n("Current line:") }
        ColorField { id: dimColor; Kirigami.FormData.label: i18n("Other lines:") }
        QQC2.CheckBox { id: tint; text: i18n("Use colors from the album cover") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Cover colors:")
            enabled: tint.checked
            model: [i18n("Multiple colors"), i18n("One color")]
            currentIndex: cfg_tintMode
            onActivated: cfg_tintMode = currentIndex
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Content") }
        QQC2.CheckBox { id: showRoman; Kirigami.FormData.label: i18n("Romanization:"); text: i18n("Replace the original with romanization when available") }
        QQC2.CheckBox { id: showNeighbours; Kirigami.FormData.label: i18n("Lines:"); text: i18n("Show the previous and next lines") }
        QQC2.CheckBox { id: animate; Kirigami.FormData.label: i18n("Animation:"); text: i18n("Swipe up and fade in on each new line") }
        QQC2.CheckBox { id: karaoke; Kirigami.FormData.label: i18n("Karaoke:"); text: i18n("Highlight each word as it is sung (when the lyrics have word timing)") }
        QQC2.CheckBox { id: compact; Kirigami.FormData.label: i18n("Small widget:"); text: i18n("Hide the previous/next lines automatically when there is no room") }
        QQC2.CheckBox { id: showHeader; Kirigami.FormData.label: i18n("Header:"); text: i18n("Show artist — title") }

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
        QQC2.CheckBox { id: showSync; text: i18n("Show sync buttons when the mouse is over the widget") }
    }
}
