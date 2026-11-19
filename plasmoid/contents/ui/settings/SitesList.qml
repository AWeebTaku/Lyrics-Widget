import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The websites a browser may play music from: each switch adds or removes that site's addresses in cfg_allowedSites.
ColumnLayout {
    id: list
    required property var kcm
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
    readonly property var current: String(kcm.cfg_allowedSites ?? "").split(",")
    function setSite(s, on) {
        const l = current.filter(h => h !== "" && s.hosts.indexOf(h) < 0)
        kcm.cfg_allowedSites = (on ? l.concat(s.hosts) : l).join(",")
    }
    spacing: 0
    Repeater {
        model: list.sites
        QQC2.CheckBox {
            required property var modelData
            text: modelData.name
            checked: list.current.indexOf(modelData.hosts[0]) >= 0
            onToggled: list.setSite(modelData, checked)
        }
    }
}
