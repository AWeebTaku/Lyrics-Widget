import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../viz/presets.js" as Presets
import "model.js" as Model
import "tokens.js" as T

// One page of Settings, drawn from model.js: a title, an optional "it is off" notice, a search box, an optional live preview
// (always on, animated) and the sections. The page file (generated) only declares the cfg_ properties and puts this inside.
// The content is a centered column (tokens.js), so a wide window does not stretch the rows.
Item {
    id: root
    required property var kcm          // the settings page: its cfg_<key> properties hold the values
    required property string pageId
    readonly property var page: Model.pageById(pageId)
    property string query: ""
    implicitHeight: col.implicitHeight + 2 * Kirigami.Units.largeSpacing
    implicitWidth: Kirigami.Units.gridUnit * 30

    // ---- the settings for the preview: every setting of the widget, as the pages show them now (an edit not yet applied counts).
    // The preview draws the widget's own code, which reads far more than one page holds.
    readonly property var cache: ({ live: null })     // a plain object: writing it does not make live() run again
    function live() {
        // while the page fills itself the preview keeps what it has (one redraw afterwards, not one per setting)
        if (kcm.loading && cache.live) return cache.live
        const o = {}
        const w = root.Window.window
        for (const k of Plasmoid.configuration.keys()) o[k] = Plasmoid.configuration[k]
        if (w && w.collect) w.collect(o)
        if (!kcm.loading) {
            for (const k of Object.keys(Presets.keys).concat(Model.pageKeys(page))) {
                const v = kcm["cfg_" + k]
                if (v !== undefined) o[k] = v
            }
        }
        cache.live = o
        return o
    }

    ColumnLayout {
        id: col
        width: Math.min(root.width - 2 * Kirigami.Units.largeSpacing, T.maxUnits * Kirigami.Units.gridUnit)
        x: (root.width - width) / 2
        y: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        PageTitle { icon: root.page.icon; title: root.page.title; subtitle: root.page.subtitle; Layout.fillWidth: true }

        // ---- "it is off" notice with a switch
        Rectangle {
            readonly property var b: root.page.banner
            visible: !!b && !Plasmoid.configuration[b.key]
            Layout.fillWidth: true
            implicitHeight: noticeRow.implicitHeight + 2 * Kirigami.Units.smallSpacing
            radius: T.radius
            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
            border.width: 1; border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.45)
            RowLayout {
                id: noticeRow
                anchors { fill: parent; margins: Kirigami.Units.smallSpacing; leftMargin: Kirigami.Units.largeSpacing }
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon { source: "dialog-information"; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
                QQC2.Label { text: parent.parent.b ? parent.parent.b.text : ""; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                QQC2.Button {
                    text: parent.parent.b ? parent.parent.b.button : ""
                    onClicked: {
                        const key = parent.parent.b.key, w = root.Window.window
                        if (w && w.setKey) w.setKey(key, true)          // also in the pages (General) that hold the old value
                        else Plasmoid.configuration[key] = true
                    }
                }
            }
        }

        // ---- search, then the live preview
        RowLayout {
            Layout.fillWidth: true
            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
                placeholderText: i18n("Search these settings")
                onTextChanged: root.query = text.trim().toLowerCase()
            }
            QQC2.ToolButton {
                visible: root.page.sections.length > 1 && root.query === ""
                icon.name: "view-list-tree"; text: i18n("Open all")
                display: QQC2.AbstractButton.TextBesideIcon
                onClicked: root.openAll(true)
            }
            QQC2.ToolButton {
                visible: root.page.sections.length > 1 && root.query === ""
                icon.name: "view-list-details"; text: i18n("Close all")
                display: QQC2.AbstractButton.TextBesideIcon
                onClicked: root.openAll(false)
            }
        }
        // the preview sits on a quiet stage, centered, so it lines up with the controls below it
        Rectangle {
            visible: !!root.page.preview
            Layout.fillWidth: true
            Layout.preferredHeight: previewLoader.item ? previewLoader.item.implicitHeight + 2 * Kirigami.Units.largeSpacing : 0
            radius: T.radius
            color: "#181c26"           // dark in every theme: the "Listen to my music" pill (white text) sits in its corner
            border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)
        Loader {
            id: previewLoader
            active: !!root.page.preview
            visible: active
            anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
            source: active ? ({ viz: "../viz/VizPreview.qml", card: "../card/CardPreview.qml", widget: "../card/CardPreview.qml", lyrics: "LyricsPreview.qml" })[root.page.preview] : ""
            onLoaded: {
                item.s = Qt.binding(() => root.live())
                if (root.page.preview === "card" || root.page.preview === "widget") {
                    item.forceCard = root.page.preview === "card"      // "widget": what the widget will show now (lyrics, visualizer or card)
                    item.viz = Qt.binding(() => root.live())
                    item.accent = Qt.binding(() => Plasmoid.configuration.cardAccentSource === 1 ? Kirigami.Theme.highlightColor : "#e0875a")
                } else {
                    item.still = Qt.binding(() => Plasmoid.configuration.reducedMotion)
                }
                if (root.page.preview === "card" || root.page.preview === "widget") {
                    item.still = Qt.binding(() => Plasmoid.configuration.reducedMotion)
                    item.live = Qt.binding(() => root.Window.window ? root.Window.window.live : null)     // the song playing now
                }
                if (root.page.preview === "lyrics") {
                    item.s = Qt.binding(() => root.live())
                    item.live = Qt.binding(() => root.Window.window ? root.Window.window.live : null)     // the song playing now
                }
            }
        }
        }

        // ---- the sections
        Repeater {
            id: sectionsRepeater
            model: root.page.sections
            Section {
                required property var modelData
                required property int index
                section: modelData
                first: index === 0
                kcm: root.kcm
                query: root.query
            }
        }
        QQC2.Label {
            visible: root.query !== "" && !root.hasAny
            text: i18n("Nothing here matches \"%1\".", root.query)
            opacity: T.muted
            Layout.alignment: Qt.AlignHCenter
        }
    }
    function openAll(on) {
        for (let i = 0; i < sectionsRepeater.count; ++i) {
            const it = sectionsRepeater.itemAt(i)
            if (it && !it.plain) it.open = on
        }
    }
    // is anything shown while searching? (the sections hide themselves when nothing in them matches)
    readonly property bool hasAny: {
        for (let i = 0; i < sectionsRepeater.count; ++i)
            if (sectionsRepeater.itemAt(i) && sectionsRepeater.itemAt(i).visible) return true
        return false
    }
}
