import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The lyrics library in a window of its own (opened by the widget's hover button)
QQC2.ApplicationWindow {
    title: i18n("Lyric Widget: lyrics library")
    // a little wider than the widget's settings window (45 x 35), so the lyrics have room
    width: Kirigami.Units.gridUnit * 56
    height: Kirigami.Units.gridUnit * 35
    minimumWidth: Kirigami.Units.gridUnit * 38
    minimumHeight: Kirigami.Units.gridUnit * 21
    color: Kirigami.Theme.backgroundColor

    LibraryEditor {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
    }
}
