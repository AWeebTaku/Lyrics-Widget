import QtQuick

// The small pill on a settings preview that switches it from made-up data to the song playing now (the sound for the
// visualizer and the card, the lyric lines for the lyrics).
Rectangle {
    id: pill
    property bool active: false
    property bool failed: false
    property string idleText
    property string activeText
    signal toggled()
    height: 24; width: label.implicitWidth + 20; radius: 12
    color: active ? "#e03daee9" : "#59ffffff"
    Accessible.role: Accessible.Button
    Accessible.name: label.text
    Text {
        id: label
        anchors.centerIn: parent
        color: pill.active ? "#00131f" : "white"
        font.pixelSize: 12; font.weight: Font.DemiBold
        text: !pill.active ? pill.idleText : pill.failed ? qsTr("Nothing to show: stop") : pill.activeText
    }
    TapHandler { onTapped: pill.toggled() }
}
