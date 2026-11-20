import QtQuick
import QtQuick.Layouts

// The widget as a pill in a panel. What it shows is set in Settings, Card, Panel: the cover (in its own shape, with a
// progress ring), a small visualizer, the title and artist (scrolling when long), a progress line, and buttons.
// It has its own look keys (pillArtShape ...) so it can differ from the card; "copy the card's look" fills them.
Item {
    id: pill
    required property var player
    required property var cfg
    property color accent: "#6a8cff"
    property color textColor: "white"
    property bool hovered: hoverArea.containsMouse
    signal clicked()
    signal middleClicked()

    readonly property bool showText: cfg.pillContent !== 3
    readonly property bool ringProgress: cfg.pillProgress === 2
    readonly property real h: Math.max(22, height > 0 ? height : 28)
    readonly property string line: cfg.pillContent === 1 ? player.title : cfg.pillContent === 2 ? player.artist
        : player.title === "" ? "♪" : (player.artist ? player.artist + " — " : "") + player.title

    Layout.minimumWidth: 28
    Layout.preferredWidth: Math.min(cfg.pillMaxWidth, row.implicitWidth + 12)
    Layout.maximumWidth: cfg.pillMaxWidth
    Layout.minimumHeight: 22
    implicitHeight: 28

    property real position: 0
    Timer {
        interval: 400; repeat: true; triggeredOnStart: true
        running: pill.visible && pill.cfg.pillProgress !== 0 && pill.player.hasPlayer
        onTriggered: pill.position = pill.player.positionSec()
    }
    readonly property real frac: player.lengthSec > 0 ? Math.max(0, Math.min(1, position / player.lengthSec)) : 0

    // the plate behind
    Rectangle {
        anchors.fill: parent; anchors.margins: 1
        radius: height / 2
        color: Qt.alpha(pill.accent, 0.16)
        border.width: 1; border.color: Qt.alpha(pill.accent, 0.45)
        visible: pill.showText || pill.cfg.pillEq !== 0
    }

    Row {
        id: row
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 }
        height: parent.height - 4
        spacing: 7

        Artwork {
            visible: pill.cfg.pillArt
            width: height; height: parent.height
            source: pill.player.artUrl
            shape: pill.cfg.pillArtShape
            borderWidth: pill.cfg.pillArtBorder
            borderColor: pill.textColor
            glow: pill.cfg.pillArtGlow
            accent: pill.accent
            playing: pill.player.playing
            spin: false
            progress: pill.ringProgress ? pill.frac : -1
        }

        // a small visualizer: bars that move (no audio capture) or the real thing (cava)
        Item {
            visible: pill.cfg.pillEq !== 0
            width: pill.cfg.pillEq === 2 ? 44 : 22; height: parent.height
            Row {
                visible: pill.cfg.pillEq === 1
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 3; height: 4 + (pill.height - 14) * (pill.player.playing ? bar : 0.15); radius: 1.5
                        color: pill.accent
                        anchors.verticalCenter: parent.verticalCenter
                        property real bar: 0.5
                        SequentialAnimation on bar {
                            running: pill.player.playing && !pill.cfg.reducedMotion && !pill.cfg.batterySaver && pill.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: 280 + index * 70 }
                            NumberAnimation { to: 0.15; duration: 320 + index * 50 }
                        }
                    }
                }
            }
            Loader {
                anchors.fill: parent
                active: pill.cfg.pillEq === 2 && pill.player.playing && pill.visible
                source: "../AudioViz.qml"
                onLoaded: {
                    item.styleOverride = pill.cfg.pillEqStyle === 0 ? 0 : 1      // bars or wave
                    item.barWidthOverride = 3
                    item.barGapOverride = 2
                    item.tintColors = Qt.binding(() => [pill.accent.toString()])
                }
            }
        }

        Column {
            visible: pill.showText
            anchors.verticalCenter: parent.verticalCenter
            // as wide as the text, up to what is left of the longest the pill may get
            readonly property real room: Math.max(40, pill.cfg.pillMaxWidth - (pill.cfg.pillArt ? pill.height + 7 : 0) - (pill.cfg.pillEq !== 0 ? 30 : 0)
                                                  - (pill.cfg.pillControls === 0 ? 20 : pill.cfg.pillControls === 1 ? 52 : 110))
            width: Math.max(40, Math.min(room, line.implicitWidth))
            spacing: 1
            MarqueeText {
                id: line
                width: parent.width
                text: pill.line
                color: pill.textColor
                pixelSize: 12
                scroll: pill.cfg.pillScroll && !pill.cfg.reducedMotion
                textStyle: pill.cfg.pillTextStyle
            }
            Rectangle {      // progress line
                visible: pill.cfg.pillProgress === 1
                width: parent.width; height: 2; radius: 1; color: Qt.alpha(pill.textColor, 0.2)
                Rectangle { width: parent.width * pill.frac; height: parent.height; radius: 1; color: pill.accent }
            }
        }

        Controls {
            visible: pill.cfg.pillControls !== 0 && (!pill.cfg.pillControlsOnHover || pill.hovered)
            width: pill.cfg.pillControls === 1 ? 32 : 100; height: parent.height
            dockStyle: pill.cfg.pillDockStyle
            playing: pill.player.playing
            showSkip: pill.cfg.pillControls === 2
            accent: pill.accent
            iconColor: pill.textColor
            onPrevious: pill.player.previousTrack()
            onToggle: pill.player.playPause()
            onNext: pill.player.nextTrack()
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        z: -1               // under the buttons
        onClicked: (m) => m.button === Qt.MiddleButton ? pill.middleClicked() : pill.clicked()
    }
}
