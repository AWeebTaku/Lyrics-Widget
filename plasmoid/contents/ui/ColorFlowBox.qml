import QtQuick
import QtQuick.Controls as QQC2

// How several colours are laid over lyrics or bars (values: see StyledText.flow)
QQC2.ComboBox {
    id: box
    property int value: 0
    signal picked(int v)
    textRole: "text"
    valueRole: "value"
    model: [
        { text: i18n("Left to right"), value: 0 },
        { text: i18n("Right to left"), value: 2 },
        { text: i18n("Top to bottom"), value: 3 },
        { text: i18n("Bottom to top"), value: 1 },
        { text: i18n("From the center"), value: 4 },
        { text: i18n("To the center"), value: 6 },
        { text: i18n("Fill (main color only)"), value: 5 }
    ]
    currentIndex: Math.max(0, indexOfValue(value))
    onActivated: picked(currentValue)
}
