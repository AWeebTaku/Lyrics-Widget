import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import org.kde.plasma.plasmoid
import "../viz/presets.js" as Presets

// The looks, as cards with a picture each (a real render of the look, made by tools/gallery/render.sh). The first cards are the
// quick ones: a random look, the look of the day, save the current settings. Clicking a look applies it right away (the page's
// own values change too); a look can set settings that live on other pages.
ColumnLayout {
    id: panel
    required property var kcm
    property string note: ""
    property string picked: ""                  // the look applied last, outlined in the grid
    readonly property var list: Presets.all(kcm.cfg_vizUserPresets, kcm.cfg_vizFavourites)
    readonly property var current: list.find(p => p.name === picked) ?? null
    readonly property int tileW: Kirigami.Units.gridUnit * 9
    readonly property int gap: Kirigami.Units.smallSpacing
    readonly property int cols: Math.max(1, Math.floor((scroll.availableWidth + gap) / (tileW + gap)))
    // the looks in groups: favorites first, then the ready-made visualizer looks, the card looks, and your own
    readonly property var groups: [
        { name: i18n("Favorites"), items: list.filter(p => p.fav) },
        { name: i18n("Visualizer"), items: list.filter(p => !p.fav && p.builtin && p.img < 16) },
        { name: i18n("Cards and layouts"), items: list.filter(p => !p.fav && p.builtin && p.img >= 16) },
        { name: i18n("Mine"), items: list.filter(p => !p.fav && !p.builtin) }
    ]
    spacing: Kirigami.Units.largeSpacing

    function apply(p) {
        if (!p) return
        const w = panel.Window.window
        for (const k in p.settings) {
            const v = p.settings[k]
            if (kcm["cfg_" + k] !== undefined) kcm["cfg_" + k] = v
            if (w && w.setKey) w.setKey(k, v)           // the other pages (General: what to show) learn it too
            else Plasmoid.configuration[k] = v
        }
        Plasmoid.configuration.writeConfig()
        picked = p.name
        note = i18n("Applied \"%1\".", p.name)
    }
    function currentSettings() {
        const o = {}
        for (const k in Presets.keys) o[k] = kcm["cfg_" + k] !== undefined ? kcm["cfg_" + k] : Plasmoid.configuration[k]
        return o
    }

    // one card: a picture area and a caption under it
    component Tile: Rectangle {
        id: tile
        property alias pic: picArea.data
        property string title
        property string caption
        property real picRatio: 0.42
        property bool selected: false
        property bool clickable: true
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: panel.tileW
        implicitHeight: col.implicitHeight
        radius: T.radius
        color: Qt.alpha(Kirigami.Theme.textColor, hover.hovered && clickable ? T.plateHover : T.plate)
        border.width: selected ? 2 : 1
        border.color: selected ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, T.hairline)
        HoverHandler { id: hover }
        QQC2.ToolTip.text: caption
        QQC2.ToolTip.visible: hover.hovered && caption !== ""
        QQC2.ToolTip.delay: 500
        TapHandler { enabled: tile.clickable; onTapped: tile.clicked() }
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            spacing: 0
            Item {
                id: picArea
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * tile.picRatio)
                clip: true
            }
            ColumnLayout {
                Layout.margins: Kirigami.Units.smallSpacing
                spacing: 0
                QQC2.Label { text: tile.title; font: Kirigami.Theme.smallFont; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    // ---- quick cards
    RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true
        Tile {
            picRatio: 0.28
            title: i18n("Random look")
            caption: i18n("Something you have not seen yet.")
            onClicked: panel.apply(Presets.randomPick(panel.list, panel.picked))
            pic: Kirigami.Icon { source: "roll"; anchors.centerIn: parent; width: Kirigami.Units.iconSizes.large; height: width }
        }
        Tile {
            picRatio: 0.28
            title: i18n("Look of the day")
            caption: i18n("The same one all day.")
            onClicked: panel.apply(Presets.dailyPick(panel.list, new Date().toISOString().slice(0, 10)))
            pic: Kirigami.Icon { source: "view-calendar-day"; anchors.centerIn: parent; width: Kirigami.Units.iconSizes.large; height: width }
        }
        Tile {
            id: saveTile
            picRatio: 0.28
            title: i18n("Save current look")
            clickable: false
            pic: RowLayout {
                anchors { fill: parent; margins: Kirigami.Units.smallSpacing }
                QQC2.TextField { id: saveName; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; maximumLength: 40; placeholderText: i18n("Name") }
                QQC2.Button {
                    Layout.alignment: Qt.AlignVCenter
                    text: i18n("Save")
                    enabled: saveName.text.trim() !== ""
                    onClicked: {
                        panel.kcm.cfg_vizUserPresets = Presets.saveUser(panel.kcm.cfg_vizUserPresets, saveName.text, panel.currentSettings())
                        panel.note = i18n("Saved \"%1\".", saveName.text.trim())
                        saveName.text = ""
                    }
                }
            }
        }
    }
    QQC2.Label { visible: panel.note !== ""; text: panel.note; wrapMode: Text.WordWrap; Layout.fillWidth: true; opacity: T.muted }

    // ---- the looks: groups of small cards in a scroll box of their own
    QQC2.ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        contentWidth: availableWidth
        clip: true
        background: Rectangle { color: "transparent"; radius: T.radius; border.width: 1; border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline) }
        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: panel.groups
                ColumnLayout {
                    id: grp
                    required property var modelData
                    visible: modelData.items.length > 0
                    Layout.fillWidth: true
                    Layout.margins: panel.gap
                    spacing: panel.gap
                    QQC2.Label { text: grp.modelData.name; font.weight: Font.DemiBold; Layout.topMargin: panel.gap }
                    GridLayout {
                        columns: panel.cols
                        columnSpacing: panel.gap
                        rowSpacing: panel.gap
                        Layout.fillWidth: true
                        Repeater {
                            model: grp.modelData.items
                            Tile {
                                id: look
                                required property var modelData
                                picRatio: 0.34
                                title: (modelData.fav ? "★ " : "") + modelData.name
                                caption: modelData.builtin ? (modelData.about ?? "") : ""
                                selected: modelData.name === panel.picked
                                onClicked: panel.apply(modelData)
                                pic: Rectangle {
                                    anchors.fill: parent
                                    color: "#181c26"
                                    Image {
                                        anchors.fill: parent
                                        visible: look.modelData.builtin
                                        source: look.modelData.builtin ? Qt.resolvedUrl("../viz/looks/" + String(look.modelData.img).padStart(2, "0") + ".png") : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        sourceSize.width: panel.tileW * 2
                                        smooth: true
                                    }
                                    QQC2.Label { visible: !look.modelData.builtin; anchors.centerIn: parent; text: look.modelData.name; color: "white"; opacity: 0.8 }
                                    Row {
                                        anchors { right: parent.right; top: parent.top }
                                        QQC2.ToolButton {
                                            icon.name: look.modelData.fav ? "starred-symbolic" : "non-starred-symbolic"
                                            padding: 2
                                            QQC2.ToolTip.text: i18n("Favorite: keeps it at the top"); QQC2.ToolTip.visible: hovered
                                            onClicked: panel.kcm.cfg_vizFavourites = Presets.toggleFav(panel.kcm.cfg_vizFavourites, look.modelData.name)
                                        }
                                        QQC2.ToolButton {
                                            visible: !look.modelData.builtin
                                            icon.name: "edit-delete"
                                            padding: 2
                                            QQC2.ToolTip.text: i18n("Delete this look of mine"); QQC2.ToolTip.visible: hovered
                                            onClicked: panel.kcm.cfg_vizUserPresets = Presets.deleteUser(panel.kcm.cfg_vizUserPresets, look.modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }
    QQC2.Label { text: i18n("Share a look as text"); font.weight: Font.DemiBold }
    QQC2.TextArea {
        id: share
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        wrapMode: TextEdit.WrapAnywhere
        font.family: "monospace"
        placeholderText: i18n("Paste a look here to import it")
    }
    RowLayout {
        QQC2.Button {
            text: panel.current ? i18n("Export \"%1\"", panel.current.name) : i18n("Export the applied look")
            enabled: !!panel.current
            onClicked: { share.text = Presets.exportText(panel.current); share.selectAll(); share.copy(); panel.note = i18n("Copied to the clipboard.") }
        }
        QQC2.Button {
            text: i18n("Import")
            enabled: share.text.trim() !== ""
            onClicked: {
                const r = Presets.importText(share.text)
                if (!r.ok) { panel.note = i18n(r.error); return }
                panel.kcm.cfg_vizUserPresets = Presets.saveUser(panel.kcm.cfg_vizUserPresets, r.preset.name, r.preset.settings)
                panel.note = i18n("Imported \"%1\" into your looks.", r.preset.name)
            }
        }
    }
}
