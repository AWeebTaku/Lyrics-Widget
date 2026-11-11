import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "wide.js" as Wide
import org.lyricwidget

KCM.SimpleKCM {
    // settings window as wide as the library window; the page may not be in its window yet when it is created
    Component.onCompleted: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    Window.onWindowChanged: Wide.grow(Window.window, Kirigami.Units.gridUnit)
    property int cfg_prefetchCount
    property int cfg_prefetchCountDefault
    property alias cfg_spotifyAppQueue: appQueue.checked
    property int cfg_spotifyDebugPort
    property bool cfg_spotifyAppQueueDefault
    property alias cfg_browserQueue: ytm.checked
    property int cfg_browserQueuePort
    property bool cfg_browserQueueDefault
    property int cfg_browserQueuePortDefault
    property int cfg_spotifyDebugPortDefault
    property alias cfg_anyPlayer: anyPlayer.checked
    property bool cfg_anyPlayerDefault
    property string cfg_allowedSites
    property string cfg_allowedSitesDefault

    SpotifyApp { id: spotify }   // only for the Test button
    BrowserSetup { id: setup }

    // Websites a browser may play music from; each switch adds or removes its addresses
    readonly property var sites: [
        { name: "YouTube", hosts: ["www.youtube.com", "youtube.com"] },
        { name: "YouTube Music", hosts: ["music.youtube.com"] },
        { name: "Spotify (web player)", hosts: ["open.spotify.com"] },
        { name: "Apple Music (web player)", hosts: ["music.apple.com"] },
        { name: "SoundCloud", hosts: ["soundcloud.com"] },
        { name: "Tidal", hosts: ["tidal.com", "listen.tidal.com"] },
        { name: "Deezer", hosts: ["www.deezer.com", "deezer.com"] },
        { name: "Bandcamp", hosts: ["bandcamp.com"] }
    ]
    function siteOn(s) { return cfg_allowedSites.split(",").includes(s.hosts[0]) }
    function setSite(s, on) {
        const l = cfg_allowedSites.split(",").filter(h => h !== "" && !s.hosts.includes(h))
        cfg_allowedSites = (on ? l.concat(s.hosts) : l).join(",")
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Next songs") }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Prepare lyrics for:")
            enabled: appQueue.checked || ytm.checked
            from: 0; to: 5
            value: cfg_prefetchCount
            textFromValue: v => v === 0 ? i18n("Off") : i18np("%1 song", "%1 songs", v)
            onValueModified: cfg_prefetchCount = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Spotify") }
        RowLayout {
            QQC2.CheckBox { id: appQueue; text: i18n("Get lyrics and the queue from the Spotify app") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Needs Spotify started with a debug port (Spicetify does this). It only reads; nothing in Spotify is changed.") }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Port:")
            enabled: appQueue.checked
            QQC2.SpinBox {
                from: 1024; to: 65535; editable: true
                value: cfg_spotifyDebugPort
                onValueModified: cfg_spotifyDebugPort = value
            }
            QQC2.Button {
                text: i18n("Test")
                onClicked: { spotify.debugPort = cfg_spotifyDebugPort; spotify.probe() }
            }
            QQC2.Label { text: spotify.appStatus; opacity: 0.8; wrapMode: Text.WordWrap; Layout.maximumWidth: Kirigami.Units.gridUnit * 18 }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("YouTube Music") }
        RowLayout {
            QQC2.CheckBox { id: ytm; text: i18n("Get the queue from YouTube Music") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("A small browser extension sends the queue to this widget. It only talks to this computer.") }
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Port:")
            enabled: ytm.checked
            from: 1024; to: 65535; editable: true
            value: cfg_browserQueuePort
            onValueModified: cfg_browserQueuePort = value
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Browser:")
            QQC2.ComboBox {
                id: browserBox
                textRole: "name"
                model: setup.browsers
                implicitWidth: Kirigami.Units.gridUnit * 12
            }
            QQC2.Button {
                text: i18n("Install extension")
                icon.name: "internet-web-browser"
                enabled: browserBox.currentIndex >= 0
                onClicked: {
                    const b = setup.browsers[browserBox.currentIndex]
                    setup.openExtensions(b.exec, b.scheme)
                    opened.visible = true
                }
            }
        }
        QQC2.Label {
            id: opened
            visible: false
            opacity: 0.8
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            text: i18n("If the browser did not open its extensions page, paste into its address bar (already on your clipboard): %1", setup.browsers[browserBox.currentIndex] ? setup.browsers[browserBox.currentIndex].scheme + "://extensions" : "")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Then choose this folder:")
            QQC2.Button { text: i18n("Copy path"); icon.name: "edit-copy"; onClicked: setup.copyPath() }
            QQC2.Button { text: i18n("Show folder"); icon.name: "folder-open"; onClicked: setup.openFolder() }
            Kirigami.ContextualHelpButton { toolTipText: i18n("In the extensions page: turn on Developer mode, click Load unpacked, press Ctrl+L and paste the path.") }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Players") }
        RowLayout {
            QQC2.CheckBox { id: anyPlayer; text: i18n("Follow any media player") }
            Kirigami.ContextualHelpButton { toolTipText: i18n("Off: Spotify and the websites below, in Chrome. On: also VLC, mpv, Strawberry, Elisa, Cider (Apple Music) and any other player that reports what it plays. Lyrics come from the usual services; the queue is only read from Spotify and YouTube Music.") }
        }
        Repeater {
            model: sites
            QQC2.CheckBox {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? i18n("Websites in the browser:") : ""
                text: modelData.name
                checked: siteOn(modelData)
                onToggled: setSite(modelData, checked)
            }
        }
    }
}
