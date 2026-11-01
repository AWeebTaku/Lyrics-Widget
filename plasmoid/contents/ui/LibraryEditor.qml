import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.lyricwidget

// The lyrics library editor: get, edit, retime and save the lyrics of the song that is playing. Used by the
// settings page and by the widget's library window. Saved lyrics win over everything the widget looks up.
Kirigami.FormLayout {

    LyricsLibrary { id: lib }

    id: root
    property bool loading: false
    // the lines the cursor or the selection is on (0-based), for "from here onwards"
    property int selFirst: 0
    property int selLast: 0
    function lineAt(pos) { return editor.text.substring(0, pos).split("\n").length - 1 }
    function updateSelection() {
        const a = editor.selectionStart, b = editor.selectionEnd
        selFirst = lineAt(a)
        // a selection that ends at the very start of a line does not include that line
        selLast = b > a ? lineAt(b - 1) : selFirst
    }
    property bool dirty: false
    readonly property var timing: lib.timing(editor.text)

    function setText(t, markDirty) {
        loading = true
        editor.text = t
        loading = false
        dirty = markDirty
        const tm = lib.timing(t)
        firstSpin.value = Math.round(tm.first)
        lastSpin.value = Math.round(tm.last)
    }
    function reloadFromSong() {
        titleField.text = lib.title
        artistField.text = lib.artist
        if (!dirty)
            setText(lib.load(), false)
    }
    Connections {
        target: lib
        function onTrackChanged() { dirty = false; reloadFromSong() }
        function onFound(text) { setText(text, true) }
    }
    Component.onCompleted: reloadFromSong()

    Kirigami.PromptDialog {
        id: confirmSearch
        title: i18n("Replace the lyrics?")
        subtitle: i18n("The text below has changes that are not saved. Searching replaces it with the search result.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: lib.search(titleField.text, artistField.text)
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Song") }
    QQC2.Label {
        Kirigami.FormData.label: i18n("Playing:")
        text: lib.hasSong ? lib.artist + " — " + lib.title + "  (" + Math.floor(lib.durationSec / 60) + ":"
                          + String(lib.durationSec % 60).padStart(2, "0") + ")"
                          : i18n("Nothing is playing")
        elide: Text.ElideRight
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
    }
    QQC2.TextField { id: titleField; Kirigami.FormData.label: i18n("Title:"); Layout.preferredWidth: Kirigami.Units.gridUnit * 20 }
    QQC2.TextField { id: artistField; Kirigami.FormData.label: i18n("Artist:"); Layout.preferredWidth: Kirigami.Units.gridUnit * 20 }
    RowLayout {
        QQC2.Button {
            text: i18n("Get lyrics")
            icon.name: "edit-find"
            enabled: titleField.text.trim() !== "" && !lib.busy
            // unsaved edits in the box would be replaced: ask first
            onClicked: dirty && editor.text.trim() !== "" ? confirmSearch.open() : lib.search(titleField.text, artistField.text)
        }
        QQC2.Button {
            text: i18n("Load saved")
            icon.name: "document-open"
            enabled: lib.hasSong
            onClicked: { dirty = false; setText(lib.load(), false) }
        }
        Kirigami.ContextualHelpButton { toolTipText: i18n("Get lyrics searches LRCLIB, NetEase, QQ Music and Kugou for the title and artist above and replaces the text below (nothing is saved until you press Save). Press it again for the next best result; Start over goes back to the best one. For a remix or edit, a title like \"Alright by Kendrick Lamar, but ...\" finds the original song, and its timing is stretched to the length of the song that is playing; or type the original title and artist yourself.") }
    }
    QQC2.Label {
        text: lib.status
        visible: lib.status !== ""
        opacity: 0.8
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Lyrics") }
    // A fixed-size frame: a bare ScrollView takes the height of its text and grows over the controls below
    Item {
        Kirigami.FormData.label: i18n("Text:")
        // the form sizes its rows by implicit size
        implicitWidth: Kirigami.Units.gridUnit * 28
        implicitHeight: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.maximumHeight: Kirigami.Units.gridUnit * 16
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
                onTextChanged: if (!loading) dirty = true
                onSelectionStartChanged: root.updateSelection()
                onSelectionEndChanged: root.updateSelection()
                onCursorPositionChanged: root.updateSelection()
            }
        }
    }
    QQC2.Label {
        opacity: 0.7
        text: timing.lines > 0
              ? i18np("%1 timed line, from %2 s to %3 s", "%1 timed lines, from %2 s to %3 s", timing.lines,
                      Math.round(timing.first), Math.round(timing.last))
              : i18n("No timed lines (plain text is shown without timing)")
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Timing") }
    RowLayout {
        Kirigami.FormData.label: i18n("Stretch or thin out (%):")
        QQC2.SpinBox { id: stretchSpin; from: 10; to: 400; value: 100; editable: true }
        QQC2.Button {
            text: i18n("Apply")
            enabled: timing.lines > 0 && stretchSpin.value !== 100
            onClicked: { setText(lib.retime(editor.text, stretchSpin.value, 0), true); stretchSpin.value = 100 }
        }
        Kirigami.ContextualHelpButton { toolTipText: i18n("Above 100 spreads the lines further apart (the song is longer than the lyrics' version). Below 100 packs them closer.") }
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Move all lines (ms):")
        QQC2.SpinBox { id: shiftSpin; from: -60000; to: 60000; stepSize: 100; value: 0; editable: true }
        QQC2.Button {
            text: i18n("Apply")
            enabled: timing.lines > 0 && shiftSpin.value !== 0
            onClicked: { setText(lib.retime(editor.text, 100, shiftSpin.value), true); shiftSpin.value = 0 }
        }
        Kirigami.ContextualHelpButton { toolTipText: i18n("Positive moves the lines later, negative earlier.") }
    }
    RowLayout {
        Kirigami.FormData.label: i18n("From the selected line (ms):")
        QQC2.SpinBox { id: partSpin; from: -60000; to: 60000; stepSize: 100; value: 0; editable: true }
        QQC2.Button {
            text: i18n("Onwards")
            enabled: timing.lines > 0 && partSpin.value !== 0
            onClicked: { setText(lib.shiftLines(editor.text, selFirst, -1, partSpin.value), true); partSpin.value = 0 }
        }
        QQC2.Button {
            text: i18n("Selection only")
            enabled: timing.lines > 0 && partSpin.value !== 0
            onClicked: { setText(lib.shiftLines(editor.text, selFirst, selLast, partSpin.value), true); partSpin.value = 0 }
        }
        Kirigami.ContextualHelpButton { toolTipText: i18n("Click a line or select several in the text above, then add (positive) or remove (negative) time. Onwards moves the first selected line and every line after it, to correct a song that drifts from that point. Selection only moves just the selected lines.") }
    }
    QQC2.Label {
        opacity: 0.7
        text: selLast > selFirst ? i18n("Selected: lines %1 to %2", selFirst + 1, selLast + 1) : i18n("Selected: line %1", selFirst + 1)
    }
    RowLayout {
        Kirigami.FormData.label: i18n("First line at (s):")
        QQC2.SpinBox { id: firstSpin; from: 0; to: 7200; editable: true }
        QQC2.Label { text: i18n("last line at (s)") }
        QQC2.SpinBox { id: lastSpin; from: 0; to: 7200; editable: true }
        QQC2.Button {
            text: i18n("Fit")
            enabled: timing.lines > 1 && lastSpin.value > firstSpin.value
            onClicked: setText(lib.fit(editor.text, firstSpin.value, lastSpin.value), true)
        }
        Kirigami.ContextualHelpButton { toolTipText: i18n("Places the first and last line at the times you give and spreads the rest evenly in between. Handy for remixes and edits: note when the first and last line are sung.") }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Library") }
    RowLayout {
        QQC2.Button {
            text: i18n("Save to library")
            icon.name: "document-save"
            enabled: lib.hasSong && editor.text.trim() !== ""
            highlighted: dirty
            onClicked: if (lib.save(editor.text, titleField.text, artistField.text)) dirty = false
        }
        QQC2.Button {
            text: i18n("Remove from library")
            icon.name: "edit-delete"
            enabled: lib.saved
            onClicked: lib.remove()
        }
        QQC2.Button {
            text: i18n("No lyrics for this song")
            icon.name: "dialog-cancel"
            enabled: lib.hasSong && !lib.ignored
            onClicked: lib.ignoreSong()
        }
        QQC2.Label {
            text: lib.ignored ? i18n("Lyrics are off for this song") : lib.saved ? i18n("This song is in your library") : i18n("Not in your library")
            opacity: 0.8
        }
    }
    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: i18n("Saved lyrics are used instead of anything the widget finds, and are kept when you rebuild. Offsets set with the hover buttons still apply on top. \"No lyrics for this song\" puts it on an ignore list so the widget stops looking it up (for a cover or edit that matches nothing). Get lyrics takes it off the list again; saving your own lyrics shows them.")
    }
}
