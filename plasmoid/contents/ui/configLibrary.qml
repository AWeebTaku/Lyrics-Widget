import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "wide.js" as Wide

// Get, edit, retime and save the lyrics of the song that is playing. Saved lyrics go into the lyrics library
// and win over everything the widget looks up.
// A page that does not scroll: the editor fits the window, lyrics and controls side by side.
KCM.AbstractKCM {
    // settings window as wide as the library window; the page may not be in its window yet when it is created
    Component.onCompleted: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    Window.onWindowChanged: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    LibraryEditor {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
    }
}
