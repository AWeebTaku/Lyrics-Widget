import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A time in seconds, two decimals ("1.50 s"). The value is in hundredths of a second: from, to and stepSize too.
QQC2.SpinBox {
    editable: true
    // wide enough for its widest text ("-500.00 s"), which a bare spin box in a narrow column cuts off
    Layout.minimumWidth: Kirigami.Units.gridUnit * 6.5
    textFromValue: v => (v / 100).toFixed(2) + " s"
    valueFromText: t => Math.round((parseFloat(t.replace(",", ".")) || 0) * 100)
}
