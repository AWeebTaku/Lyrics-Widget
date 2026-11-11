import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "wide.js" as Wide
import org.kde.plasma.plasmoid

// Where things sit in the widget
KCM.SimpleKCM {
    // settings window as wide as the library window; the page may not be in its window yet when it is created
    Component.onCompleted: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    Window.onWindowChanged: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    property int cfg_lyricsHAlign
    property int cfg_lyricsVAlign
    property int cfg_lyricsOffsetX
    property int cfg_lyricsOffsetY
    property int cfg_vizWidthPct
    property int cfg_vizHeightPct
    property int cfg_vizHAlign
    property int cfg_vizVAlign
    property int cfg_vizOffsetX
    property int cfg_vizOffsetY

    property int cfg_lyricsHAlignDefault
    property int cfg_lyricsVAlignDefault
    property int cfg_lyricsOffsetXDefault
    property int cfg_lyricsOffsetYDefault
    property int cfg_vizWidthPctDefault
    property int cfg_vizHeightPctDefault
    property int cfg_vizHAlignDefault
    property int cfg_vizVAlignDefault
    property int cfg_vizOffsetXDefault
    property int cfg_vizOffsetYDefault

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
                AlignGrid {
                    Kirigami.FormData.label: i18n("Position:")
                    h: cfg_lyricsHAlign; v: cfg_lyricsVAlign
                    onPicked: (hh, vv) => { cfg_lyricsHAlign = hh; cfg_lyricsVAlign = vv }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Move right / down (px):")
                    QQC2.SpinBox {
                        from: -4000; to: 4000; stepSize: 5; editable: true
                        value: cfg_lyricsOffsetX
                        onValueModified: cfg_lyricsOffsetX = value
                    }
                    QQC2.SpinBox {
                        from: -4000; to: 4000; stepSize: 5; editable: true
                        value: cfg_lyricsOffsetY
                        onValueModified: cfg_lyricsOffsetY = value
                    }
                }
            }
            Kirigami.FormLayout {
                enabled: (Plasmoid.configuration?.showVisualizer ?? true)
                QQC2.Label {
                    visible: !(Plasmoid.configuration?.showVisualizer ?? true)
                    text: i18n("The visualizer is off (General page).")
                    opacity: 0.7
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Width / height (%):")
                    QQC2.SpinBox { from: 0; to: 100; value: cfg_vizWidthPct; onValueModified: cfg_vizWidthPct = value }
                    QQC2.SpinBox { from: 0; to: 100; value: cfg_vizHeightPct; onValueModified: cfg_vizHeightPct = value }
                }
                AlignGrid {
                    Kirigami.FormData.label: i18n("Position:")
                    h: cfg_vizHAlign; v: cfg_vizVAlign
                    onPicked: (hh, vv) => { cfg_vizHAlign = hh; cfg_vizVAlign = vv }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Move right / down (px):")
                    QQC2.SpinBox {
                        from: -4000; to: 4000; stepSize: 5; editable: true
                        value: cfg_vizOffsetX
                        onValueModified: cfg_vizOffsetX = value
                    }
                    QQC2.SpinBox {
                        from: -4000; to: 4000; stepSize: 5; editable: true
                        value: cfg_vizOffsetY
                        onValueModified: cfg_vizOffsetY = value
                    }
                }
            }
        }
    }
}
