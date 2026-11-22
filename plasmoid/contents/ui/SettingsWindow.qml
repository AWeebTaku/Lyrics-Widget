import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.lyricwidget
import org.kde.kirigami as Kirigami
import "settings"
import "settings/model.js" as Model
import "settings/tokens.js" as T

// A widget's settings in a window of its own. Plasma shows only one settings dialog at a time (opening the settings of a second
// widget closes the first); this window belongs to one widget, so several can be open together, one for each. It shows the same
// pages as Plasma's dialog, filled from `cfg` (the widget's configuration), and writes back to it on Apply.
QQC2.ApplicationWindow {
    id: win
    property var cfg                      // the widget's configuration (Plasmoid.configuration)
    property var live: null               // the widget's lyrics controller: the previews can show the song playing now
    property string widgetName: ""        // what this widget is set to show (its layout), so the windows can be told apart
    property int current: 0
    property var seen: [true, false, false, false, false, false, false]
    property string note: ""
    signal libraryRequested()

    title: widgetName !== "" ? i18n("Lyric Widget settings: %1", widgetName) : i18n("Lyric Widget settings")
    // sized to the screen it opens on (a fixed size was taller than a 768 px screen), never larger than the screen allows
    readonly property real availW: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : 1280
    readonly property real availH: Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight : 720
    width: Math.min(Kirigami.Units.gridUnit * 58, availW * 0.9)
    height: Math.min(Kirigami.Units.gridUnit * 40, availH * 0.88)
    minimumWidth: Math.min(Kirigami.Units.gridUnit * 34, availW * 0.9)
    minimumHeight: Math.min(Kirigami.Units.gridUnit * 20, availH * 0.88)
    color: Kirigami.Theme.backgroundColor


    // open in the middle of the screen (the compositor places a new window in the area the panels leave free, and a window
    // that resizes after it opens drifts): ask KWin to center it, a few times while it settles
    WindowPlacer { id: placer }
    Timer {
        id: centerTimer
        property int runs: 0
        interval: 300; repeat: true
        running: win.visible && runs < 3
        onTriggered: { placer.center(Qt.resolvedUrl("../kwin/center.js")); ++runs }
    }

    readonly property var pages: Model.pages
    readonly property var files: ({ general: "GeneralPanel", lyrics: "LyricsPanel", visualizer: "VisualizerPanel", audio: "AudioPanel",
                                    card: "CardPanel", looks: "LooksPanel", sources: "SourcesPanel" })

    function panel(i) { return panels.itemAt(i) ? panels.itemAt(i).item : null }
    function load() {
        if (!cfg) return
        for (let i = 0; i < panels.count; ++i) {
            const it = panel(i)
            if (it) it.load(cfg)
        }
    }
    // Put the pages' values over `o` (a copy of the saved settings): what the previews draw. One pass over the pages' own keys.
    function collect(o) {
        for (let i = 0; i < panels.count; ++i) {
            const it = panel(i)
            if (!it || it.loading) continue
            for (const k of it.keys) {
                const v = it["cfg_" + k]
                if (v !== undefined) o[k] = v
            }
        }
    }
    // The value of one setting as the pages show it now: an edit not yet applied counts
    function get(key) {
        for (let i = 0; i < panels.count; ++i) {
            const it = panel(i)
            if (it && it["cfg_" + key] !== undefined) return it["cfg_" + key]
        }
        return cfg ? cfg[key] : undefined
    }
    // Set one setting right away (the "Turn it on" notices, applying a look): in the widget's configuration, and in every page that
    // has loaded it, so a page does not write its older value back on Apply (the General page's "show the visualizer" switch).
    function setKey(key, value) {
        if (!cfg) return
        cfg[key] = value
        for (let i = 0; i < panels.count; ++i) {
            const it = panel(i)
            if (it && it["cfg_" + key] !== undefined) it["cfg_" + key] = value
        }
    }
    // the page being built (a page is made the first time it is opened)
    readonly property bool building: panels.count > current && panels.itemAt(current) !== null && panels.itemAt(current).status === Loader.Loading
    // edits not applied yet, counted while the window is open (the footer shows them; Apply waits for them)
    property int pending: 0
    function countPending() {
        let n = 0
        if (cfg) for (let i = 0; i < panels.count; ++i) { const it = panel(i); if (it) n += it.changes(cfg) }
        return n
    }
    Timer { interval: 300; repeat: true; running: win.visible; onTriggered: win.pending = win.countPending() }
    // write what changed on every page that has been opened
    function apply() {
        if (!cfg) return
        let changed = 0
        for (let i = 0; i < panels.count; ++i) {
            const it = panel(i)
            if (it) changed += it.save(cfg)
        }
        if (changed > 0) cfg.writeConfig()
        pending = 0
        note = changed > 0 ? i18n("Applied: %1 changed.", changed) : i18n("Nothing to apply.")
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- the pages
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
            spacing: 0
            ColumnLayout {      // which widget this is
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                spacing: 0
                QQC2.Label { text: i18n("Lyric Widget"); font.weight: Font.DemiBold; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * T.sectionScale) }
                QQC2.Label { text: win.widgetName; visible: text !== ""; opacity: T.muted; elide: Text.ElideRight; Layout.fillWidth: true
                             font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * T.smallScale) }
            }
            ListView {
                id: pageList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                model: win.pages
                spacing: 2
                clip: true
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    highlighted: win.current === index
                    text: modelData.title
                    icon.name: modelData.icon
                    onClicked: {
                        win.current = index
                        const s = win.seen.slice(); s[index] = true; win.seen = s
                    }
                }
            }
            QQC2.ItemDelegate {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                text: i18n("Lyrics library…")
                icon.name: "document-edit"
                onClicked: win.libraryRequested()
            }
        }
        Kirigami.Separator { Layout.fillHeight: true }

        // ---- the page, and the buttons
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.current
                Repeater {
                    id: panels
                    model: win.pages
                    // a page is built when first opened, and kept
                    Loader {
                        required property var modelData
                        required property int index
                        active: win.seen[index] === true
                        asynchronous: true       // built a piece at a time: the window keeps answering while a big page is made
                        source: win.files[modelData.id] ? Qt.resolvedUrl("settings/" + win.files[modelData.id] + ".qml") : ""
                        onLoaded: if (win.cfg) item.load(win.cfg)
                    }
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            RowLayout {
                Layout.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                QQC2.BusyIndicator { running: win.building; visible: running; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium; Layout.preferredWidth: Layout.preferredHeight }
                // what the footer says: edits waiting for Apply, else the last thing that happened
                QQC2.Label {
                    text: win.building ? i18n("Opening the page…") : win.pending > 0 ? i18n("%1 changes not applied yet", win.pending) : win.note
                    font.weight: win.pending > 0 && !win.building ? Font.DemiBold : Font.Normal
                    opacity: win.pending > 0 ? 1 : T.muted
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                QQC2.Button { text: win.pending > 0 ? i18n("Discard and close") : i18n("Close"); icon.name: "window-close"; onClicked: win.close() }
                QQC2.Button { text: i18n("OK"); icon.name: "dialog-ok"; onClicked: { win.apply(); win.close() } }
                QQC2.Button { text: i18n("Apply"); icon.name: "dialog-ok-apply"; highlighted: win.pending > 0; enabled: win.pending > 0; onClicked: win.apply() }
            }
        }
    }
}
