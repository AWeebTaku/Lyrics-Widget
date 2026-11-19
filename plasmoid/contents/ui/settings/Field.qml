import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Qt.labs.folderlistmodel
import org.kde.kirigami as Kirigami
import "../viz/palettes.js" as Palettes
import "model.js" as Model

// One setting: its name on the left, its control on the right, and what it does in small print underneath. The control is
// chosen by the row's type (model.js); it reads and writes the page's cfg_<key> directly.
ColumnLayout {
    id: f
    required property var row
    required property var kcm
    readonly property real labelWidth: Kirigami.Units.gridUnit * 14
    readonly property bool wide: ["presets", "colors", "eq", "spotify", "browser", "sites", "info", "align2"].indexOf(row.type) >= 0
    readonly property var value: row.key ? kcm["cfg_" + row.key] : undefined
    spacing: 2

    function get(key) { return kcm["cfg_" + key] }
    function put(key, v) { if (kcm["cfg_" + key] !== v) kcm["cfg_" + key] = v }

    // ---- name and control on one line
    RowLayout {
        visible: !f.wide
        spacing: Kirigami.Units.largeSpacing
        QQC2.Label {
            text: f.row.label ?? ""
            wrapMode: Text.WordWrap
            Layout.preferredWidth: f.labelWidth
            Layout.maximumWidth: f.labelWidth
            Layout.alignment: Qt.AlignVCenter
        }
        Loader {
            active: f.visible && !f.wide
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: f.row.type === "text"
            sourceComponent: {
                switch (f.row.type) {
                case "bool": return boolC
                case "int": return intC
                case "real": return realC
                case "combo": return comboC
                case "color": return colorC
                case "text": return textC
                case "file": return fileC
                case "font": return fontC
                case "flow": return flowC
                case "pair": return pairC
                case "align": return alignC
                case "palette": return paletteC
                case "source": return sourceC
                }
                return null
            }
        }
    }
    // ---- the larger controls take the whole width, under their name
    QQC2.Label { visible: f.wide && !!f.row.label; text: f.row.label ?? ""; font.weight: Font.DemiBold }
    Loader {
        active: f.visible && f.wide
        visible: f.wide
        Layout.fillWidth: true
        sourceComponent: {
            switch (f.row.type) {
            case "presets": return presetsC
            case "colors": return colorsC
            case "eq": return eqC
            case "spotify": return spotifyC
            case "browser": return browserC
            case "sites": return sitesC
            case "info": return infoC
            }
            return null
        }
    }
    QQC2.Label {
        visible: !!f.row.hint
        text: f.row.hint ?? ""
        wrapMode: Text.WordWrap
        opacity: 0.62
        font: Kirigami.Theme.smallFont
        Layout.leftMargin: f.wide ? 0 : f.labelWidth + Kirigami.Units.largeSpacing
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 36
    }

    // ---- the controls
    Component { id: boolC; QQC2.Switch { checked: !!f.value; onToggled: f.put(f.row.key, checked) } }
    Component {
        id: intC
        QQC2.SpinBox {
            readonly property var u: f.row.unit
            readonly property real div: u && u.div ? u.div : 1
            from: f.row.min ?? 0
            to: f.row.max ?? 9999
            stepSize: f.row.step ?? 1
            editable: true
            value: f.value ?? 0
            textFromValue: v => (f.row.off !== undefined && v === from) ? f.row.off
                : (div !== 1 ? (v / div).toFixed(u.decimals ?? 2) : String(v)) + (u && u.suffix ? u.suffix : "")
            valueFromText: t => { const n = parseFloat(String(t).replace(",", ".")); return isNaN(n) ? value : Math.max(from, Math.min(to, Math.round(n * div))) }
            onValueModified: f.put(f.row.key, value)
        }
    }
    Component {
        id: realC
        QQC2.SpinBox {
            readonly property real k: f.row.scale ?? 100
            from: f.row.min ?? 0
            to: f.row.max ?? 100
            editable: true
            value: Math.round((f.value ?? 0) * k)
            textFromValue: v => v + "%"
            valueFromText: t => { const n = parseFloat(String(t)); return isNaN(n) ? value : Math.max(from, Math.min(to, Math.round(n))) }
            onValueModified: f.put(f.row.key, value / k)
        }
    }
    Component {
        id: comboC
        QQC2.ComboBox {
            model: f.row.options
            implicitContentWidthPolicy: QQC2.ComboBox.WidestText
            currentIndex: f.row.values ? f.row.values.indexOf(f.value) : (f.value ?? 0)
            onActivated: f.put(f.row.key, f.row.values ? f.row.values[currentIndex] : currentIndex)
        }
    }
    Component {
        id: flowC
        QQC2.ComboBox {
            model: Model.flows
            implicitContentWidthPolicy: QQC2.ComboBox.WidestText
            currentIndex: Math.max(0, Model.flowValues.indexOf(f.value))
            onActivated: f.put(f.row.key, Model.flowValues[currentIndex])
        }
    }
    Component {
        id: paletteC
        QQC2.ComboBox {
            model: Palettes.palettes.map(p => p.name)
            implicitContentWidthPolicy: QQC2.ComboBox.WidestText
            currentIndex: f.value ?? 0
            onActivated: f.put(f.row.key, currentIndex)
        }
    }
    Component { id: colorC; ColorSwatch { alpha: !!f.row.alpha; value: f.value ?? "#ffffff"; onPicked: v => f.put(f.row.key, v) } }
    Component {
        id: textC
        QQC2.TextField {
            text: f.value ?? ""
            placeholderText: f.row.placeholder ?? ""
            Layout.fillWidth: true
            onEditingFinished: f.put(f.row.key, text)
        }
    }
    Component {
        id: fontC
        RowLayout {
            QQC2.TextField { readOnly: true; text: f.value || i18n("System default"); Layout.preferredWidth: Kirigami.Units.gridUnit * 12; opacity: f.value ? 1 : 0.6 }
            QQC2.Button { text: i18n("Choose…"); onClicked: fontDialog.active = true }
            QQC2.Button { icon.name: "edit-clear"; enabled: !!f.value; onClicked: f.put(f.row.key, "") }
            Loader {
                id: fontDialog
                active: false
                sourceComponent: FontDialog {
                    onAccepted: { f.put(f.row.key, selectedFont.family); fontDialog.active = false }
                    onRejected: fontDialog.active = false
                    Component.onCompleted: open()
                }
            }
        }
    }
    Component {
        id: pairC
        RowLayout {
            QQC2.SpinBox {
                from: f.row.min ?? 0; to: f.row.max ?? 9999; stepSize: f.row.step ?? 1; editable: true
                value: f.get(f.row.keys[0]) ?? 0
                onValueModified: f.put(f.row.keys[0], value)
            }
            QQC2.Label { text: "×" }
            QQC2.SpinBox {
                from: f.row.min ?? 0; to: f.row.max ?? 9999; stepSize: f.row.step ?? 1; editable: true
                value: f.get(f.row.keys[1]) ?? 0
                onValueModified: f.put(f.row.keys[1], value)
            }
        }
    }
    Component {
        id: alignC
        AlignPicker {
            h: f.get(f.row.keys[0]) ?? 1
            v: f.get(f.row.keys[1]) ?? 1
            onPicked: (hh, vv) => { f.put(f.row.keys[0], hh); f.put(f.row.keys[1], vv) }
        }
    }
    // a .qml file from ~/.local/share/lyric-widget/<folder>/
    Component {
        id: fileC
        ColumnLayout {
            FolderListModel {
                id: files
                folder: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/lyric-widget/" + (f.row.folder ?? "visualizers")
                nameFilters: ["*.qml"]
                showDirs: false
            }
            QQC2.ComboBox {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                model: files.count > 0 ? Array.from({ length: files.count }, (_, i) => files.get(i, "fileName")) : [i18n("(no files yet)")]
                enabled: files.count > 0
                currentIndex: {
                    const cur = String(f.value ?? "")
                    for (let i = 0; i < files.count; ++i)
                        if (cur.endsWith("/" + files.get(i, "fileName"))) return i
                    return -1
                }
                onActivated: f.put(f.row.key, files.get(currentIndex, "filePath"))
            }
            QQC2.Label { text: i18n("Put .qml files in ~/.local/share/lyric-widget/%1/", f.row.folder ?? "visualizers"); opacity: 0.6; font: Kirigami.Theme.smallFont }
        }
    }
    Component { id: sourceC; SourceField { value: f.value ?? ""; onPicked: v => f.put(f.row.key, v) } }
    Component { id: colorsC; ColorSpec { kind: f.row.spec; value: f.value ?? "{}"; onEdited: json => f.put(f.row.key, json) } }
    Component {
        id: eqC
        EqEditor {
            bands: f.value ?? []
            fromFreq: f.get("lowerCutoffFreq") ?? 50
            toFreq: f.get("higherCutoffFreq") ?? 10000
            onEdited: b => f.put(f.row.key, b)
        }
    }
    Component { id: presetsC; PresetsPanel { kcm: f.kcm } }
    Component { id: spotifyC; SpotifyCheck { kcm: f.kcm } }
    Component { id: browserC; BrowserSetupRow {} }
    Component { id: sitesC; SitesList { kcm: f.kcm } }
    Component { id: infoC; QQC2.Label { text: f.row.text ?? ""; wrapMode: Text.WordWrap; opacity: 0.8 } }
}
