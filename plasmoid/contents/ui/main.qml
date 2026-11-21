import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// The thin shell around the widget. The widget itself is Widget.qml; it needs the C++ plugin (org.lyricwidget). When that plugin is
// not installed (the usual case after installing from the KDE Store, which carries QML only), Widget.qml cannot load, and the
// widget shows Setup.qml instead of Plasma's error: one button that installs the plugin. Everything the PlasmoidItem must own
// (the menu entry, the two representations, the sizes) is set here from what Widget.qml exposes.
PlasmoidItem {
    id: shell
    readonly property var w: core.item                          // the widget, once it has loaded
    readonly property bool missing: core.status === Loader.Error

    Loader {
        id: core
        source: "Widget.qml"
        onLoaded: item.shell = shell
    }

    // "Configure…" opens this widget's settings in a window of its own (Plasma shows only one settings dialog at a time)
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Configure %1…", Plasmoid.title)
            icon.name: "configure"
            visible: !shell.missing
            onTriggered: if (shell.w) shell.w.openSettingsWindow()
        }
    ]
    Component.onCompleted: Plasmoid.removeInternalAction("configure")      // replaced by the entry above

    preferredRepresentation: w && w.compactPreferred ? compactRepresentation : fullRepresentation
    compactRepresentation: Loader { sourceComponent: shell.w ? shell.w.compactComp : setupCompact }
    fullRepresentation: Loader { sourceComponent: shell.w ? shell.w.fullComp : setupFull }
    Component { id: setupFull; Setup {} }
    Component { id: setupCompact; Setup { compact: true } }

    hideOnWindowDeactivate: !(w && w.pinned)
    Plasmoid.backgroundHints: w ? w.backgroundHints : PlasmaCore.Types.DefaultBackground
    Layout.minimumWidth: w ? w.minW : 280
    Layout.preferredWidth: w ? w.prefW : 360
    Layout.maximumWidth: w ? w.maxW : Number.POSITIVE_INFINITY
    Layout.minimumHeight: w ? w.minH : 200
    Layout.preferredHeight: w ? w.prefH : 240
    Layout.maximumHeight: w ? w.maxH : Number.POSITIVE_INFINITY
}
