import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../viz/presets.js" as Presets
import "model.js" as Model
import "tokens.js" as T

// One page of Settings, drawn from model.js: a title, an optional "it is off" notice, a search box, an optional live preview
// (off until asked for) and the sections. The page file (generated) only declares the cfg_ properties and puts this inside.
// The content is a centered column (tokens.js), so a wide window does not stretch the rows.
Item {
    id: root
    required property var kcm          // the settings page: its cfg_<key> properties hold the values
    required property string pageId
    readonly property var page: Model.pageById(pageId)
    property string query: ""
    property bool previewOn: false     // the preview is what made the old pages slow: only when asked for
    implicitHeight: col.implicitHeight + 2 * Kirigami.Units.largeSpacing
    implicitWidth: Kirigami.Units.gridUnit * 30

    // ---- the settings for the preview: the page's unsaved values over the saved ones
    function live() {
        const o = {}
        const keys = Object.keys(Presets.keys).concat(Model.pageKeys(page))
        for (const k of keys) {
            const v = kcm["cfg_" + k]
            o[k] = v !== undefined ? v : Plasmoid.configuration[k]
        }
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
            color: Qt.alpha(Kirigami.Theme.textColor, T.plate)
            border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)
            RowLayout {
                id: noticeRow
                anchors { fill: parent; margins: Kirigami.Units.smallSpacing; leftMargin: Kirigami.Units.largeSpacing }
                QQC2.Label { text: parent.parent.b ? parent.parent.b.text : ""; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                QQC2.Button {
                    text: parent.parent.b ? parent.parent.b.button : ""
                    onClicked: Plasmoid.configuration[parent.parent.b.key] = true
                }
            }
        }

        // ---- search and preview
        RowLayout {
            Layout.fillWidth: true
            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
                placeholderText: i18n("Search these settings")
                onTextChanged: root.query = text.trim().toLowerCase()
            }
            QQC2.Switch {
                visible: !!root.page.preview
                text: i18n("Live preview")
                checked: root.previewOn
                onToggled: root.previewOn = checked
            }
        }
        Loader {
            active: root.previewOn && !!root.page.preview
            visible: active
            Layout.fillWidth: true
            Layout.preferredHeight: active ? (item ? item.implicitHeight : 0) : 0
            source: active ? (root.page.preview === "viz" ? "../viz/VizPreview.qml" : "../card/CardPreview.qml") : ""
            onLoaded: {
                item.s = Qt.binding(() => root.live())
                if (root.page.preview === "card") {
                    item.forceCard = true
                    item.viz = Qt.binding(() => root.live())
                    item.accent = Qt.binding(() => Plasmoid.configuration.cardAccentSource === 1 ? Kirigami.Theme.highlightColor : "#e0875a")
                } else {
                    item.still = Qt.binding(() => Plasmoid.configuration.reducedMotion)
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
    // is anything shown while searching? (the sections hide themselves when nothing in them matches)
    readonly property bool hasAny: {
        for (let i = 0; i < sectionsRepeater.count; ++i)
            if (sectionsRepeater.itemAt(i) && sectionsRepeater.itemAt(i).visible) return true
        return false
    }
}
