import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.lyricwidget

// The lyrics library editor: get, edit, retime and save the lyrics of the song that is playing. Used by the
// settings page and by the widget's library window. Saved lyrics win over everything the widget looks up.
// Two columns so that the text and all its controls are in view at once: the lyrics on the left, the song,
// timing and library controls on the right.
Item {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 40
    implicitHeight: Kirigami.Units.gridUnit * 28

    LyricsLibrary { id: lib }

    property bool loading: false
    property bool dirty: false
    readonly property var timing: lib.timing(editor.text)
    // the lines the cursor or the selection is on (0-based), for "from the selected line"
    property int selFirst: 0
    property int selLast: 0
    function lineAt(pos) { return editor.text.substring(0, pos).split("\n").length - 1 }
    function updateSelection() {
        const a = editor.selectionStart, b = editor.selectionEnd
        selFirst = lineAt(a)
        // a selection that ends at the very start of a line does not include that line
        selLast = b > a ? lineAt(b - 1) : selFirst
        refreshLine()
    }

    // the selected line's time in the spin box
    function refreshLine() {
        const t = lib.lineTime(editor.text, selFirst)
        lineSpin.value = t < 0 ? 0 : Math.round(t * 100)
    }

    // the selected line gets the song's current time; the cursor moves on to the next line
    function stampNow() {
        const pos = lib.playheadSec()
        if (pos < 0 || editor.text.length === 0)
            return
        const line = selFirst
        setText(lib.setLineTime(editor.text, line, pos), true)
        const lines = editor.text.split("\n")
        let at = 0
        for (let i = 0; i <= Math.min(line, lines.length - 1); ++i)
            at += lines[i].length + 1
        editor.cursorPosition = Math.min(at, editor.text.length)
        editor.forceActiveFocus()
    }

    function setText(t, markDirty) {
        loading = true
        editor.text = t
        loading = false
        dirty = markDirty
        const tm = lib.timing(t)
        firstSpin.value = Math.round(tm.first * 100)
        lastSpin.value = Math.round(tm.last * 100)
    }
    function reloadFromSong() {
        titleField.text = lib.title
        artistField.text = lib.artist
        if (!dirty)
            setText(lib.load(), false)
    }
    Connections {
        target: lib
        function onTrackChanged() { root.dirty = false; root.reloadFromSong() }
        function onFound(text) { root.setText(text, true) }
    }
    Component.onCompleted: reloadFromSong()

    Kirigami.PromptDialog {
        id: confirmSearch
        title: i18n("Replace the lyrics?")
        subtitle: i18n("The text has changes that are not saved. Searching replaces it with the search result.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: lib.search(titleField.text, artistField.text)
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // ---- left: the lyrics
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: i18n("Lyrics"); font.bold: true }
            Item { // a fixed frame: a bare ScrollView takes the height of its text and grows over the rest
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Kirigami.Theme.backgroundColor
                    border.width: 1
                    border.color: Kirigami.Theme.disabledTextColor
                }
                QQC2.ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    QQC2.TextArea {
                        id: editor
                        font.family: "monospace"
                        wrapMode: TextEdit.NoWrap
                        selectByMouse: true
                        persistentSelection: true // the selection stays while a button is pressed
                        background: null
                        placeholderText: i18n("Lyrics, one line each. A line starts with its time: [01:23.45] text")
                        onTextChanged: { if (!root.loading) root.dirty = true; root.refreshLine() }
                        onSelectionStartChanged: root.updateSelection()
                        onSelectionEndChanged: root.updateSelection()
                        onCursorPositionChanged: root.updateSelection()
                    }
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.7
                text: (root.timing.lines > 0
                       ? i18np("%1 timed line, %2 s to %3 s", "%1 timed lines, %2 s to %3 s", root.timing.lines,
                               Math.round(root.timing.first), Math.round(root.timing.last))
                       : i18n("No timed lines"))
                      + "  ·  " + (root.selLast > root.selFirst ? i18n("selected: lines %1 to %2", root.selFirst + 1, root.selLast + 1)
                                                                 : i18n("selected: line %1", root.selFirst + 1))
            }

            // play the song and press this (or Ctrl+Enter) as each line starts: the selected line gets the playhead's
            // time and the next line is selected. Fine-tune afterwards with the timing controls.
            RowLayout {
                QQC2.Button {
                    text: i18n("Stamp line at playhead")
                    icon.name: "media-record"
                    enabled: editor.text.length > 0
                    onClicked: root.stampNow()
                }
                QQC2.Label { text: i18n("Ctrl+Enter"); opacity: 0.6 }
            }
            Shortcut { sequence: "Ctrl+Return"; onActivated: root.stampNow() }
        }

        // ---- right: song, timing, library
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: i18n("Song"); font.bold: true }
            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: lib.hasSong ? lib.artist + " — " + lib.title + "  (" + Math.floor(lib.durationSec / 60) + ":"
                                    + String(lib.durationSec % 60).padStart(2, "0") + ")"
                                  : i18n("Nothing is playing")
            }
            QQC2.TextField { id: titleField; Layout.fillWidth: true; placeholderText: i18n("Title") }
            QQC2.TextField { id: artistField; Layout.fillWidth: true; placeholderText: i18n("Artist") }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.Button {
                    text: i18n("Get lyrics")
                    icon.name: "edit-find"
                    enabled: titleField.text.trim() !== "" && !lib.busy
                    // unsaved edits in the box would be replaced: ask first
                    onClicked: root.dirty && editor.text.trim() !== "" ? confirmSearch.open() : lib.search(titleField.text, artistField.text)
                }
                QQC2.Button {
                    text: i18n("Start over")
                    enabled: !lib.busy
                    onClicked: { lib.startOver(); lib.search(titleField.text, artistField.text) }
                }
                QQC2.Button {
                    text: i18n("Load saved")
                    enabled: lib.hasSong
                    onClicked: { root.dirty = false; root.setText(lib.load(), false) }
                }
                Kirigami.ContextualHelpButton { toolTipText: i18n("Get lyrics searches LRCLIB, NetEase, QQ Music and Kugou for the title and artist above and replaces the text (nothing is saved until you press Save). Press it again for the next best result; Start over goes back to the best one. For a remix or edit, a title like \"Alright by Kendrick Lamar, but ...\" finds the original song, stretched to the length of the song that is playing.") }
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: lib.status
                visible: lib.status !== ""
                opacity: 0.8
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing
                QQC2.Label { text: i18n("Timing"); font.bold: true }
                Kirigami.ContextualHelpButton { toolTipText: i18n("Stretch: above 100% spreads the lines apart (the song is longer than the lyrics' version), below 100 packs them closer. Shift: positive moves lines later, negative earlier. From the selected line: click a line or select several in the text, then Onwards moves the first selected line and every line after it (for a song that drifts from that point), Selected only moves just the selected lines. Fit places the first and last line at the times you give and spreads the rest evenly (handy for remixes and edits).") }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                QQC2.Label { text: i18n("Stretch (%)") }
                QQC2.SpinBox { id: stretchSpin; from: 10; to: 400; value: 100; editable: true; Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Apply")
                    enabled: root.timing.lines > 0 && stretchSpin.value !== 100
                    onClicked: { root.setText(lib.retime(editor.text, stretchSpin.value, 0), true); stretchSpin.value = 100 }
                }

                QQC2.Label { text: i18n("Shift all (s)") }
                SecondsSpinBox { id: shiftSpin; from: -6000; to: 6000; stepSize: 10; value: 0; Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Apply")
                    enabled: root.timing.lines > 0 && shiftSpin.value !== 0
                    onClicked: { root.setText(lib.retime(editor.text, 100, shiftSpin.value * 10), true); shiftSpin.value = 0 }
                }

                QQC2.Label { text: i18n("From line (s)") }
                SecondsSpinBox { id: partSpin; from: -6000; to: 6000; stepSize: 10; value: 0; Layout.fillWidth: true }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Button {
                        text: i18n("Onwards")
                        enabled: root.timing.lines > 0 && partSpin.value !== 0
                        onClicked: { root.setText(lib.shiftLines(editor.text, root.selFirst, -1, partSpin.value * 10), true); partSpin.value = 0 }
                    }
                    QQC2.Button {
                        text: i18n("Selected")
                        enabled: root.timing.lines > 0 && partSpin.value !== 0
                        onClicked: { root.setText(lib.shiftLines(editor.text, root.selFirst, root.selLast, partSpin.value * 10), true); partSpin.value = 0 }
                    }
                }

                QQC2.Label { text: i18n("Selected line at (s)") }
                SecondsSpinBox { id: lineSpin; from: 0; to: 720000; stepSize: 10; Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Set")
                    enabled: editor.text.length > 0
                    onClicked: root.setText(lib.setLineTime(editor.text, root.selFirst, lineSpin.value / 100), true)
                }

                QQC2.Label { text: i18n("First (s)") }
                SecondsSpinBox { id: firstSpin; from: 0; to: 720000; stepSize: 100; Layout.fillWidth: true }
                Item { Layout.preferredWidth: 1 }

                QQC2.Label { text: i18n("Last (s)") }
                SecondsSpinBox { id: lastSpin; from: 0; to: 720000; stepSize: 100; Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Fit")
                    enabled: root.timing.lines > 1 && lastSpin.value > firstSpin.value
                    onClicked: root.setText(lib.fit(editor.text, firstSpin.value / 100, lastSpin.value / 100), true)
                }
            }

            QQC2.Label { text: i18n("Library"); font.bold: true; Layout.topMargin: Kirigami.Units.smallSpacing }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.Button {
                    text: i18n("Save")
                    icon.name: "document-save"
                    enabled: lib.hasSong && editor.text.trim() !== ""
                    highlighted: root.dirty
                    onClicked: if (lib.save(editor.text, titleField.text, artistField.text)) root.dirty = false
                }
                QQC2.Button {
                    text: i18n("Remove")
                    icon.name: "edit-delete"
                    enabled: lib.saved
                    onClicked: lib.remove()
                }
                QQC2.Button {
                    text: i18n("No lyrics")
                    icon.name: "dialog-cancel"
                    enabled: lib.hasSong && !lib.ignored
                    onClicked: lib.ignoreSong()
                }
                Kirigami.ContextualHelpButton { toolTipText: i18n("Save keeps these lyrics for the song: they are used instead of anything the widget finds, and are kept when you rebuild. Remove deletes them. No lyrics puts the song on an ignore list so the widget stops looking it up (for a cover or edit that matches nothing); Get lyrics takes it off the list again, and saving your own lyrics shows them.") }
            }
            QQC2.Label {
                Layout.fillWidth: true
                opacity: 0.8
                elide: Text.ElideRight
                text: lib.ignored ? i18n("Lyrics are off for this song") : lib.saved ? i18n("This song is in your library") : i18n("Not in your library")
            }
            Item { Layout.fillHeight: true }
        }
    }
}
