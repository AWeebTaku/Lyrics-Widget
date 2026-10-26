import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The lyrics library in a window of its own (opened by the widget's hover button)
QQC2.ApplicationWindow {
    title: i18n("Lyric Widget: lyrics library")
    // the size of the widget's settings window (Plasma's own: 45 x 35, at least 30 x 21)
    width: Kirigami.Units.gridUnit * 45
    height: Kirigami.Units.gridUnit * 35
    minimumWidth: Kirigami.Units.gridUnit * 30
    minimumHeight: Kirigami.Units.gridUnit * 21
    color: Kirigami.Theme.backgroundColor

    QQC2.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        LibraryEditor {
            width: parent.width
            // the form needs room around it
        }
    }
}
