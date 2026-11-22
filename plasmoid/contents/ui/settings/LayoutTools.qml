import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tokens.js" as T
import "../card/layouts.js" as Layouts

// Put the changes made to the parts of a layout back: every part of the layout in use, or of every layout.
RowLayout {
    id: tools
    required property var kcm
    spacing: Kirigami.Units.smallSpacing
    QQC2.Button {
        text: i18n("Reset this layout")
        icon.name: "edit-undo"
        onClicked: tools.kcm.cfg_layoutEdits = Layouts.resetEdits(tools.kcm.cfg_layoutEdits, tools.kcm.cfg_layoutMode ?? 2)
    }
    QQC2.Button { text: i18n("Reset every layout"); onClicked: tools.kcm.cfg_layoutEdits = "{}" }
}
