import QtQuick
import QtQuick.Controls as QQC2

// Title, artist and (optionally) album. Text looks: 0 plain, 1 shadow, 2 frosted (on a pale translucent plate).
// A title or artist that is too long scrolls back and forth while it is wider than its place (off with reduced motion).
Item {
    id: root
    property string title
    property string artist
    property string album
    property bool showAlbum: false
    property int textStyle: 0
    property bool scroll: true
    property bool calm: false
    property bool headline: false        // poster: the title is big and may take two lines
    property int titleSize: 15
    property int maxHeadlineLines: 2
    property int align: Text.AlignLeft
    property color textColor: "white"
    property color titleColor: textColor     // the song title (the artist keeps dimColor)
    property color dimColor: "#b0ffffff"
    property string fontFamily: ""
    property bool hovered: false
    signal clicked()

    implicitHeight: col.implicitHeight
    clip: true

    Rectangle {      // frosted plate
        visible: root.textStyle === 2
        anchors.fill: col
        anchors.margins: -6
        radius: 8
        color: "#26ffffff"
        border.width: 1; border.color: "#33ffffff"
    }

    // one line that scrolls when it does not fit
    component Line: Item {
        id: ln
        property string text
        property int size: 14
        property bool bold: false
        property color color: "white"
        implicitHeight: label.implicitHeight
        width: parent.width
        clip: true
        readonly property bool overflow: label.implicitWidth > width + 1
        Text {
            id: label
            text: ln.text
            color: ln.color
            font.pixelSize: ln.size
            font.bold: ln.bold
            font.family: root.fontFamily
            style: root.textStyle === 1 ? Text.Raised : Text.Normal
            styleColor: "#aa000000"
            elide: ln.overflow && root.scroll && !root.calm ? Text.ElideNone : Text.ElideRight
            width: ln.overflow && root.scroll && !root.calm ? implicitWidth : ln.width
            horizontalAlignment: root.align
            x: ln.overflow ? 0 : 0
            SequentialAnimation on x {
                running: ln.overflow && root.scroll && !root.calm && root.visible
                loops: Animation.Infinite
                PauseAnimation { duration: 1500 }
                NumberAnimation { to: -(label.implicitWidth - ln.width); duration: Math.max(1500, (label.implicitWidth - ln.width) * 30) }
                PauseAnimation { duration: 1200 }
                NumberAnimation { to: 0; duration: 600 }
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: root.headline ? 6 : 1
        Text {
            visible: root.headline
            width: parent.width
            text: root.title
            color: root.titleColor
            font.pixelSize: Math.max(22, Math.min(54, root.height * 0.34))
            font.bold: true
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            maximumLineCount: root.maxHeadlineLines
            elide: Text.ElideRight
            horizontalAlignment: root.align
            style: root.textStyle === 1 ? Text.Raised : Text.Normal
            styleColor: "#aa000000"
        }
        Line { visible: !root.headline; text: root.title; size: root.titleSize; bold: true; color: root.titleColor }
        Line { text: root.artist; size: root.headline ? 16 : 12; color: root.dimColor; visible: root.artist !== "" }
        Line { text: root.album; size: 11; color: root.dimColor; visible: root.showAlbum && root.album !== ""; opacity: 0.8 }
    }

    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked(); onEntered: root.hovered = true; onExited: root.hovered = false }
}
