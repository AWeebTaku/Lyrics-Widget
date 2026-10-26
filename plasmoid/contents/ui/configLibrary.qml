import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Get, edit, retime and save the lyrics of the song that is playing. Saved lyrics go into the lyrics library
// and win over everything the widget looks up.
KCM.SimpleKCM {
    LibraryEditor { width: parent.width }
}
