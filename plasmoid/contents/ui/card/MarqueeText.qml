import QtQuick

// One line of text that scrolls back and forth while it is wider than its place (and stays put otherwise).
Item {
    id: root
    property string text
    property color color: "white"
    property int pixelSize: 12
    property bool bold: false
    property string fontFamily: ""
    property bool scroll: true
    property int align: Text.AlignLeft
    property int textStyle: 0           // 0 plain, 1 shadow
    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth
    clip: true
    readonly property bool overflow: label.implicitWidth > width + 1
    Text {
        id: label
        text: root.text
        color: root.color
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        font.family: root.fontFamily
        style: root.textStyle === 1 ? Text.Raised : Text.Normal
        styleColor: "#aa000000"
        elide: root.overflow && root.scroll ? Text.ElideNone : Text.ElideRight
        width: root.overflow && root.scroll ? implicitWidth : root.width
        horizontalAlignment: root.align
        SequentialAnimation on x {
            running: root.overflow && root.scroll && root.visible
            loops: Animation.Infinite
            PauseAnimation { duration: 1500 }
            NumberAnimation { to: -(label.implicitWidth - root.width); duration: Math.max(1500, (label.implicitWidth - root.width) * 30) }
            PauseAnimation { duration: 1200 }
            NumberAnimation { to: 0; duration: 600 }
        }
    }
}
