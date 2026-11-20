import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.lyricwidget
import QtQuick.Window
import "wide.js" as Wide

// The lyrics library in a window of its own (opened by the widget's hover button)
QQC2.ApplicationWindow {
    title: i18n("Lyric Widget: lyrics library")
    // as wide as the settings window (see wide.js) so the lyrics have room, but never larger than the screen it opens on
    readonly property real availW: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : 1280
    readonly property real availH: Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight : 720
    width: Math.min(Kirigami.Units.gridUnit * Wide.units, availW * 0.92)
    height: Math.min(Kirigami.Units.gridUnit * 38, availH * 0.9)
    minimumWidth: Math.min(Kirigami.Units.gridUnit * 38, availW * 0.92)
    minimumHeight: Math.min(Kirigami.Units.gridUnit * 21, availH * 0.9)
    color: Kirigami.Theme.backgroundColor

    // open in the middle of the screen (the compositor places a new window in the area the panels leave free, and a window
    // that resizes after it opens drifts): ask KWin to center it, a few times while it settles
    WindowPlacer { id: placer }
    Timer {
        id: centerTimer
        property int runs: 0
        interval: 300; repeat: true
        running: visible && runs < 3
        onTriggered: { placer.center(Qt.resolvedUrl("../kwin/center.js")); ++runs }
    }

    LibraryEditor {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
    }
}
