import QtQuick
import org.kde.kirigami as Kirigami

// Previous, play / pause, next, and optionally shuffle and repeat, in one of six button looks:
// 0 glass, 1 soft, 2 outline, 3 tinted, 4 bare (icons only), 5 accent play (only play is filled)
Item {
    id: root
    property int dockStyle: 0
    property bool playing: false
    property bool showSkip: true
    property bool showShuffleRepeat: false
    property bool shuffle: false
    property string loop: "None"          // None, Track, Playlist
    property color accent: "#6a8cff"
    property color iconColor: "white"
    property string align: "center"       // "left", "center" or "right" in the space it is given
    signal previous()
    signal toggle()
    signal next()
    signal toggleShuffle()
    signal cycleLoop()

    implicitHeight: 36
    implicitWidth: row.implicitWidth

    component Btn: Item {
        id: b
        property string icon
        property bool primary: false
        property bool active: false
        signal clicked()
        readonly property int size: primary ? Math.min(root.height, 40) : Math.min(root.height, 32)
        width: size; height: size
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: root.dockStyle !== 4 && !(root.dockStyle === 5 && !b.primary)
            color: root.dockStyle === 0 ? (ma.containsMouse ? "#40ffffff" : "#22ffffff")
                 : root.dockStyle === 1 ? (ma.containsMouse ? "#66000000" : "#40000000")
                 : root.dockStyle === 2 ? "transparent"
                 : root.dockStyle === 3 ? Qt.alpha(root.accent, ma.containsMouse ? 0.55 : 0.35)
                 : (b.primary ? root.accent : "transparent")
            border.width: root.dockStyle === 0 ? 1 : root.dockStyle === 2 ? 1.5 : 0
            border.color: root.dockStyle === 0 ? "#44ffffff" : root.iconColor
            opacity: root.dockStyle === 2 && !ma.containsMouse ? 0.8 : 1
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.52; height: width
            source: b.icon
            color: root.dockStyle === 5 && b.primary ? "#101010" : b.active ? root.accent : root.iconColor
            opacity: ma.containsMouse || b.active || b.primary ? 1 : 0.85
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: root.align === "left" ? 0 : root.align === "right" ? parent.width - width : (parent.width - width) / 2
        spacing: 8
        Btn { visible: root.showShuffleRepeat; icon: "media-playlist-shuffle"; active: root.shuffle; onClicked: root.toggleShuffle() }
        Btn { visible: root.showSkip; icon: "media-skip-backward"; onClicked: root.previous() }
        Btn { primary: true; icon: root.playing ? "media-playback-pause" : "media-playback-start"; onClicked: root.toggle() }
        Btn { visible: root.showSkip; icon: "media-skip-forward"; onClicked: root.next() }
        Btn { visible: root.showShuffleRepeat; icon: root.loop === "Track" ? "media-playlist-repeat-song" : "media-playlist-repeat"; active: root.loop !== "None"; onClicked: root.cycleLoop() }
    }
}
