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
    property alias cfg_showNeighbours: showNeighbours.checked
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
    property bool cfg_showNeighboursDefault
    property bool cfg_karaokeDefault
    property bool cfg_showHeaderDefault
    property bool cfg_animateLinesDefault
    property int cfg_offsetMsDefault
    property bool cfg_showSyncControlsDefault

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Lyrics") }
        QQC2.CheckBox { id: showLyrics; text: i18n("Show lyrics") }

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
        QQC2.CheckBox { id: boldCurrent; text: i18n("Bold current line") }

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

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Show") }
        QQC2.CheckBox { id: showRoman; text: i18n("Romanized text (Japanese, Korean, Chinese)") }
        QQC2.CheckBox { id: showNeighbours; text: i18n("Previous and next lines") }
        QQC2.CheckBox { id: karaoke; text: i18n("Word-by-word highlight") }
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
        QQC2.CheckBox { id: showSync; text: i18n("Show sync buttons when the mouse is over the widget") }
    }
}
