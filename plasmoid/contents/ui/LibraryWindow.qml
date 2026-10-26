import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The lyrics library in a window of its own (opened by the widget's hover button)
QQC2.ApplicationWindow {
    title: i18n("Lyric Widget: lyrics library")
    width: Kirigami.Units.gridUnit * 38
    height: Kirigami.Units.gridUnit * 40
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
