import QtQuick
import org.kde.kirigami as Kirigami
import "tokens.js" as T

// Where something sits in its space: a 3 x 3 grid. h: 0 left, 1 center, 2 right; v: 0 top, 1 middle, 2 bottom.
Grid {
    id: grid
    property int h: 1
    property int v: 1
    signal picked(int h, int v)
    columns: 3
    spacing: 3
    Repeater {
        model: 9
        Rectangle {
            id: cell
            required property int index
            readonly property bool on: grid.h === index % 3 && grid.v === Math.floor(index / 3)
            width: Kirigami.Units.gridUnit * 1.6; height: width
            radius: T.radiusSmall
            color: on ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, hover.hovered ? 0.16 : T.plateHover)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, T.hairline)
            HoverHandler { id: hover }
            TapHandler { onTapped: grid.picked(cell.index % 3, Math.floor(cell.index / 3)) }
        }
    }
}
