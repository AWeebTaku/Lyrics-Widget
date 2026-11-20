import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T

// The equalizer: one slider per band, from the lowest pitch on the left to the highest on the right.
// `bands` is a list of strings ("1.0" = unchanged); an edit is handed back as a new list (never edited in place).
ColumnLayout {
    id: eq
    property var bands: []
    property real fromFreq: 50
    property real toFreq: 10000
    signal edited(var bands)

    function freqLabel(i) {
        const n = Math.max(1, bands.length)
        const f = fromFreq * Math.pow(Math.max(toFreq, fromFreq + 1) / fromFreq, (i + 0.5) / n)
        return f >= 1000 ? (f / 1000).toFixed(f >= 10000 ? 0 : 1) + "k" : Math.round(f).toString()
    }
    function setBand(i, v) { const c = bands.slice(); c[i] = v.toFixed(1); eq.edited(c) }

    RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Repeater {
            model: eq.bands.length
            ColumnLayout {
                id: col
                required property int index
                spacing: 2
                QQC2.Label { text: parseFloat(eq.bands[col.index]).toFixed(1); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignHCenter }
                QQC2.Slider {
                    orientation: Qt.Vertical
                    from: 0; to: 2; stepSize: 0.1
                    value: parseFloat(eq.bands[col.index])
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                    Layout.alignment: Qt.AlignHCenter
                    onMoved: eq.setBand(col.index, value)
                }
                QQC2.Label { text: eq.freqLabel(col.index); font: Kirigami.Theme.smallFont; opacity: T.muted; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
    RowLayout {
        QQC2.Button { text: i18n("Add a band"); icon.name: "list-add"; enabled: eq.bands.length < 32; onClicked: eq.edited(eq.bands.concat(["1.0"])) }
        QQC2.Button { text: i18n("Remove a band"); icon.name: "list-remove"; enabled: eq.bands.length > 1; onClicked: eq.edited(eq.bands.slice(0, -1)) }
        QQC2.Button { text: i18n("Flat"); onClicked: eq.edited(eq.bands.map(() => "1.0")) }
    }
}
