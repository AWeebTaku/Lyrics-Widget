import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// 3x3 position picker: h 0 left / 1 centre / 2 right, v 0 top / 1 middle / 2 bottom
Item {
    id: root
    property int h: 1
    property int v: 1
    signal picked(int h, int v)

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        columns: 3
        rowSpacing: 2
        columnSpacing: 2
        Repeater {
            model: 9
            QQC2.Button {
                required property int index
                readonly property int col: index % 3
                readonly property int row: Math.floor(index / 3)
                implicitWidth: 34
                implicitHeight: 24
                highlighted: root.h === col && root.v === row
                text: highlighted ? "●" : ""
                onClicked: root.picked(col, row)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: [i18n("Top"), i18n("Middle"), i18n("Bottom")][row] + " "
                                   + [i18n("left"), i18n("centre"), i18n("right")][col]
            }
        }
    }
}
