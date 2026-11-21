import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

// Shown instead of the widget when its C++ plugin (org.lyricwidget) is not installed, for example after installing from the KDE
// Store. It has no import of the plugin on purpose. One button opens a terminal that downloads the installer of the same version
// as this widget and builds the plugin (plugin only; the widget files are the ones the Store installed). The Store package carries
// the plugin's source and the installer (contents/installer), so nothing is downloaded and the plugin matches this widget's
// version. A copy of the package without them (a plain source folder) downloads the release instead. The installer asks for the
// password once and restarts Plasma when it is done, which brings the widget up.
Item {
    id: setup
    property bool compact: false
    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 16

    readonly property string ver: Plasmoid.metaData && Plasmoid.metaData.version ? Plasmoid.metaData.version : ""
    readonly property string tag: ver !== "" ? "v" + ver : ""
    readonly property string url: "https://github.com/AWeebTaku/Lyrics-Widget/releases/" + (tag !== "" ? "download/" + tag : "latest/download") + "/lyric-widget.sh"
    // the installer and the source that came in the package (the folder of this file is contents/ui)
    readonly property string here: decodeURIComponent(Qt.resolvedUrl("..").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string bundled: here + "/installer"
    FolderListModel { id: bundle; folder: "file://" + encodeURI(setup.bundled); nameFilters: ["lyric-widget.sh"]; showDirs: false }
    readonly property bool hasBundle: bundle.count > 0
    // the same line a person could paste into a terminal
    readonly property string command: hasBundle
        ? 'bash "' + bundled + '/lyric-widget.sh" install --plugin-only --source "' + bundled + '/source"' + (tag !== "" ? " --version " + tag : "")
        : 'f=$(mktemp) && curl -fsSLo "$f" ' + url + ' && bash "$f" install --plugin-only' + (tag !== "" ? " --version " + tag : "")

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
    }
    function install() {
        exec.connectSource("konsole --hold -e bash -c '" + setup.command + "'")
        started.visible = true
    }
    TextEdit { id: clip; visible: false }
    function copyCommand() { clip.text = setup.command; clip.selectAll(); clip.copy(); copied.visible = true }

    // in a panel: just the icon; clicking opens the same screen as a popup
    Kirigami.Icon {
        visible: setup.compact
        anchors.fill: parent
        source: "dialog-warning"
        TapHandler { onTapped: Plasmoid.expanded = !Plasmoid.expanded }
        QQC2.ToolTip.visible: hoverHandler.hovered
        QQC2.ToolTip.text: i18n("Lyric Widget needs its plugin. Click to install it.")
        HoverHandler { id: hoverHandler }
    }

    ColumnLayout {
        visible: !setup.compact
        anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
        spacing: Kirigami.Units.largeSpacing
        Item { Layout.fillHeight: true }
        Kirigami.Icon { source: "org.lyricwidget"; fallback: "dialog-warning"; Layout.preferredWidth: Kirigami.Units.iconSizes.huge; Layout.preferredHeight: Kirigami.Units.iconSizes.huge; Layout.alignment: Qt.AlignHCenter }
        QQC2.Label { text: i18n("Lyric Widget needs its plugin"); font.bold: true; font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.3); Layout.alignment: Qt.AlignHCenter }
        QQC2.Label {
            text: i18n("The widget's lyric lookup and visualizer are a small program that the KDE Store cannot install. One click builds it on this computer from the source in this package and asks for your password once. Plasma restarts when it is done.")
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; opacity: 0.8
            Layout.fillWidth: true
        }
        QQC2.Button { text: i18n("Install the plugin"); icon.name: "system-software-install"; highlighted: true; Layout.alignment: Qt.AlignHCenter; onClicked: setup.install() }
        QQC2.Button { text: i18n("Copy the command instead"); flat: true; Layout.alignment: Qt.AlignHCenter; onClicked: setup.copyCommand() }
        QQC2.Label { id: started; visible: false; text: i18n("A terminal opened: follow it, then this widget appears."); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; opacity: 0.8; Layout.fillWidth: true }
        QQC2.Label { id: copied; visible: false; text: i18n("Copied. Paste it into a terminal."); horizontalAlignment: Text.AlignHCenter; opacity: 0.8; Layout.fillWidth: true }
        QQC2.Label {
            text: i18n("Needs Plasma 6, Qt 6, cmake and a C++ compiler (installed for you on Arch Linux).")
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; opacity: 0.6; font: Kirigami.Theme.smallFont
            Layout.fillWidth: true
        }
        Item { Layout.fillHeight: true }
    }
}
