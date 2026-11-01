import QtQuick
import QtQuick.Controls as QQC2

// A time in seconds, two decimals ("1.50 s"). The value is in hundredths of a second: from, to and stepSize too.
QQC2.SpinBox {
    editable: true
    textFromValue: v => (v / 100).toFixed(2) + " s"
    valueFromText: t => Math.round((parseFloat(t.replace(",", ".")) || 0) * 100)
}
