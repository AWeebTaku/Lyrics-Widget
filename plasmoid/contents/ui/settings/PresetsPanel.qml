import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../viz/presets.js" as Presets

// The visualizer's looks: pick a ready-made one, make a random one, save your own, share as text. Applying a look writes the
// widget's settings right away (the page's own values change too); a look can set settings that live on other pages.
ColumnLayout {
    id: panel
    required property var kcm
    property string note: ""
    readonly property var list: Presets.all(kcm.cfg_vizUserPresets, kcm.cfg_vizFavourites)
    readonly property var current: list[box.currentIndex] ?? null
    spacing: Kirigami.Units.smallSpacing

    function apply(p) {
        if (!p) return
        for (const k in p.settings) {
            const v = p.settings[k]
            if (kcm["cfg_" + k] !== undefined) kcm["cfg_" + k] = v
            Plasmoid.configuration[k] = v
        }
        Plasmoid.configuration.writeConfig()
        note = i18n("Applied \"%1\". Close and reopen Settings to see every value on the other pages.", p.name)
    }
    function currentSettings() {
        const o = {}
        for (const k in Presets.keys) o[k] = kcm["cfg_" + k] !== undefined ? kcm["cfg_" + k] : Plasmoid.configuration[k]
        return o
    }

    RowLayout {
        Layout.fillWidth: true
        QQC2.ComboBox {
            id: box
            Layout.fillWidth: true
            model: panel.list.map(p => (p.fav ? "★ " : "") + p.name + (p.builtin ? "" : "  (mine)"))
        }
        QQC2.Button { text: i18n("Apply"); highlighted: true; onClicked: panel.apply(panel.current) }
        QQC2.Button {
            icon.name: panel.current && panel.current.fav ? "starred-symbolic" : "non-starred-symbolic"
            QQC2.ToolTip.text: i18n("Favorite: keeps it at the top of the list"); QQC2.ToolTip.visible: hovered
            onClicked: { if (panel.current) { panel.kcm.cfg_vizFavourites = Presets.toggleFav(panel.kcm.cfg_vizFavourites, panel.current.name); box.currentIndex = 0 } }
        }
        QQC2.Button {
            icon.name: "edit-delete"
            enabled: !!panel.current && !panel.current.builtin
            QQC2.ToolTip.text: i18n("Delete this look of mine"); QQC2.ToolTip.visible: hovered
            onClicked: panel.kcm.cfg_vizUserPresets = Presets.deleteUser(panel.kcm.cfg_vizUserPresets, panel.current.name)
        }
    }
    QQC2.Label {
        visible: text !== ""
        text: panel.current ? (panel.current.about ?? "") : ""
        opacity: 0.75; wrapMode: Text.WordWrap
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 34
    }
    RowLayout {
        QQC2.Button { text: i18n("Random look"); icon.name: "roll"; onClicked: panel.apply(Presets.randomPick(panel.list, panel.current ? panel.current.name : "")) }
        QQC2.Button { text: i18n("Look of the day"); icon.name: "view-calendar-day"; onClicked: panel.apply(Presets.dailyPick(panel.list, new Date().toISOString().slice(0, 10))) }
    }
    QQC2.Label {
        text: i18n("A look sets the style, sizes, reactions, color mode and effects together, and is applied to the widget right away.")
        opacity: 0.6; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont
        Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 34
    }
    Kirigami.Separator { Layout.fillWidth: true }
    QQC2.Label { text: i18n("Save the current settings as a look"); font.weight: Font.DemiBold }
    RowLayout {
        QQC2.TextField { id: saveName; Layout.fillWidth: true; maximumLength: 40; placeholderText: i18n("Name") }
        QQC2.Button {
            text: i18n("Save")
            enabled: saveName.text.trim() !== ""
            onClicked: {
                panel.kcm.cfg_vizUserPresets = Presets.saveUser(panel.kcm.cfg_vizUserPresets, saveName.text, panel.currentSettings())
                saveName.text = ""
            }
        }
    }
    QQC2.Label { visible: panel.note !== ""; text: panel.note; wrapMode: Text.WordWrap; Layout.fillWidth: true; opacity: 0.85 }
    QQC2.Label { text: i18n("Share a look as text"); font.weight: Font.DemiBold }
    QQC2.TextArea {
        id: share
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
        wrapMode: TextEdit.WrapAnywhere
        font.family: "monospace"
        placeholderText: i18n("Export fills this box; paste someone else's look here and press Import.")
    }
    RowLayout {
        QQC2.Button {
            text: i18n("Export the selected look")
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
