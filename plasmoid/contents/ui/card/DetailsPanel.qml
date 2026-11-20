import QtQuick

// The details of the playing song in four groups: Song, Credits, Release, Playback. Release and Credits come from the
// online lookup when it is on; without it they are left out.
Rectangle {
    id: root
    property string title
    property string artist
    property string album
    property real lengthSec: 0
    property real positionSec: 0
    property real volume: 1
    property bool shuffle: false
    property string loop: "None"
    property bool online: false
    property bool busy: false
    property string year
    property string country
    property string label
    property string tags
    property string about
    property color textColor: "white"
    property color accent: "#6a8cff"

    radius: 10
    color: "#e6141820"
    border.width: 1; border.color: "#33ffffff"
    implicitHeight: col.implicitHeight + 20

    function fmt(sec) { sec = Math.max(0, Math.round(sec)); return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0") }

    component Head: Text { color: root.accent; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase; topPadding: 4 }
    component Row2: Row {
        property string name; property string value
        visible: value !== ""
        spacing: 8
        Text { text: parent.name; color: root.textColor; opacity: 0.6; font.pixelSize: 12; width: 70 }
        Text { text: parent.value; color: root.textColor; font.pixelSize: 12; width: root.width - 20 - 78; elide: Text.ElideRight; wrapMode: Text.NoWrap }
    }

    Column {
        id: col
        x: 10; y: 10; width: parent.width - 20
        spacing: 2
        Head { text: qsTr("Song") }
        Row2 { name: qsTr("Title"); value: root.title }
        Row2 { name: qsTr("Artist"); value: root.artist }
        Row2 { name: qsTr("Album"); value: root.album }
        Row2 { name: qsTr("Length"); value: root.lengthSec > 0 ? root.fmt(root.lengthSec) : "" }
        Head { visible: root.online; text: qsTr("Credits") }
        Text { visible: root.online && root.about !== ""; width: parent.width; text: root.about; color: root.textColor; opacity: 0.85; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight }
        Text { visible: root.online && root.busy; text: qsTr("Looking it up…"); color: root.textColor; opacity: 0.6; font.pixelSize: 11 }
        Head { visible: root.online && (root.year !== "" || root.label !== "" || root.country !== "" || root.tags !== ""); text: qsTr("Release") }
        Row2 { name: qsTr("Year"); value: root.online ? root.year : "" }
        Row2 { name: qsTr("Label"); value: root.online ? root.label : "" }
        Row2 { name: qsTr("Country"); value: root.online ? root.country : "" }
        Row2 { name: qsTr("Tags"); value: root.online ? root.tags : "" }
        Head { text: qsTr("Playback") }
        Row2 { name: qsTr("Position"); value: root.fmt(root.positionSec) + " / " + root.fmt(root.lengthSec) }
        Row2 { name: qsTr("Volume"); value: Math.round(root.volume * 100) + "%" }
        Row2 { name: qsTr("Shuffle"); value: root.shuffle ? qsTr("On") : qsTr("Off") }
        Row2 { name: qsTr("Repeat"); value: root.loop === "Track" ? qsTr("Track") : root.loop === "Playlist" ? qsTr("All") : qsTr("Off") }
    }
}
