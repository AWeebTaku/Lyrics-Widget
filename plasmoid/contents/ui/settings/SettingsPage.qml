import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../viz/presets.js" as Presets
import "model.js" as Model

// One page of Settings, drawn from model.js: a header, an optional "it is off" notice, a search box, an optional live preview
// (off until asked for) and the sections. The page file (generated) only declares the cfg_ properties and puts this inside.
ColumnLayout {
    id: root
    required property var kcm          // the settings page: its cfg_<key> properties hold the values
    required property string pageId
    readonly property var page: Model.pageById(pageId)
    property string query: ""
    property bool previewOn: false     // the preview is what made the old pages slow: only when asked for
    spacing: Kirigami.Units.largeSpacing

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

    // ---- header
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Rectangle {
            implicitWidth: Kirigami.Units.gridUnit * 2.6
            implicitHeight: implicitWidth
            radius: Kirigami.Units.gridUnit * 0.8
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.lighter(Kirigami.Theme.highlightColor, 1.15) }
                GradientStop { position: 1; color: Qt.darker(Kirigami.Theme.highlightColor, 1.25) }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.medium; height: width
                source: root.page.icon
                color: Kirigami.Theme.highlightedTextColor
                isMask: true
            }
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            QQC2.Label { text: root.page.title; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.55); font.weight: Font.DemiBold }
            QQC2.Label { text: root.page.subtitle; opacity: 0.65; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }

    // ---- "it is off" notice with a switch
    RowLayout {
        readonly property var b: root.page.banner
        visible: !!b && !Plasmoid.configuration[b.key]
        Layout.fillWidth: true
        QQC2.Label { text: parent.b ? parent.b.text : ""; opacity: 0.8; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        QQC2.Button {
            text: parent.b ? parent.b.button : ""
            icon.name: "media-playback-start"
            onClicked: Plasmoid.configuration[parent.b.key] = true
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
            section: modelData
            kcm: root.kcm
            query: root.query
        }
    }
    QQC2.Label {
        visible: root.query !== "" && !root.hasAny
        text: i18n("Nothing here matches \"%1\".", root.query)
        opacity: 0.7
        Layout.alignment: Qt.AlignHCenter
    }
    // is anything shown while searching? (the sections hide themselves when nothing in them matches)
    readonly property bool hasAny: {
        for (let i = 0; i < sectionsRepeater.count; ++i)
            if (sectionsRepeater.itemAt(i) && sectionsRepeater.itemAt(i).visible) return true
        return false
    }
}
