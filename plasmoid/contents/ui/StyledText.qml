pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// One line of lyric text with the user's text style: font weight / italic / underline / spacing / case, a
// shadow (optionally blurred), an outline and a highlight bar behind the line. All the style comes from
// `cfg` (Plasmoid.configuration); the caller gives the size, colour and layout of the line.
Item {
    id: root

    required property var cfg
    property bool isCurrent: false          // the line being sung: weight and highlight differ
    property string text
    property color color: "white"
    // Several colours spread over the text: flow 0 left to right, 1 bottom to top, 2 right to left,
    // 3 top to bottom, 4 from the centre outwards, 6 from the edges inwards, 5 fill (just `color`)
    property var colors: []
    property int flow: 5
    readonly property bool gradientOn: colors.length > 1 && flow !== 5
    readonly property bool vertical: flow === 1 || flow === 3
    // where the text really is (the gradient spans the text, not the whole item)
    readonly property real textLeft: horizontalAlignment === Text.AlignLeft ? 0
        : horizontalAlignment === Text.AlignRight ? width - contentWidth : (width - contentWidth) / 2
    readonly property real textTop: verticalAlignment === Text.AlignVCenter ? (height - contentHeight) / 2
        : verticalAlignment === Text.AlignBottom ? height - contentHeight : 0
    readonly property real spanStart: vertical ? (height > 0 ? textTop / height : 0) : (width > 0 ? textLeft / width : 0)
    readonly property real span: vertical ? (height > 0 ? contentHeight / height : 1) : (width > 0 ? contentWidth / width : 1)
    // [{pos, color}] for the gradient, at most 7 entries (4 colours from the centre outwards)
    readonly property var stops: {
        const n = colors.length, out = []
        if (n < 2) return out
        const ordered = (flow === 2 || flow === 1) ? colors.slice().reverse() : colors
        if (flow === 4 || flow === 6) {
            const cs = flow === 6 ? colors.slice().reverse() : colors
            for (let i = n - 1; i >= 0; --i) out.push({pos: spanStart + span * (0.5 - 0.5 * i / (n - 1)), color: cs[i]})
            for (let i = 1; i < n; ++i) out.push({pos: spanStart + span * (0.5 + 0.5 * i / (n - 1)), color: cs[i]})
        } else {
            for (let i = 0; i < n; ++i) out.push({pos: spanStart + span * i / (n - 1), color: ordered[i]})
        }
        return out
    }
    property int pixelSize: 20
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignTop
    property int wrapMode: Text.NoWrap
    property int maximumLineCount: 1
    property int fontSizeMode: Text.FixedSize
    property int minimumPixelSize: 1
    property int elide: Text.ElideRight

    readonly property real contentWidth: face.contentWidth
    readonly property real contentHeight: face.contentHeight
    readonly property int lineCount: face.lineCount

    // ---- highlight bar behind the line (the current one only)
    Rectangle {
        visible: root.isCurrent && root.cfg.highlightOn && root.text !== ""
        radius: root.cfg.highlightRadius
        color: root.cfg.highlightColor
        width: root.contentWidth + 2 * root.cfg.highlightPadX
        height: root.contentHeight + 2 * root.cfg.highlightPadY
        x: (root.horizontalAlignment === Text.AlignLeft ? 0
            : root.horizontalAlignment === Text.AlignRight ? root.width - root.contentWidth
            : (root.width - root.contentWidth) / 2) - root.cfg.highlightPadX
        y: (root.verticalAlignment === Text.AlignVCenter ? (root.height - root.contentHeight) / 2
            : root.verticalAlignment === Text.AlignBottom ? root.height - root.contentHeight : 0) - root.cfg.highlightPadY
    }

    // one copy of the text; the shadow and the outline are more copies, drawn behind in other colours
    component Face: Text {
        property real dx: 0
        property real dy: 0
        x: dx
        y: dy
        width: root.width
        height: root.height
        text: root.text
        color: root.color
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        fontSizeMode: root.fontSizeMode
        minimumPixelSize: root.minimumPixelSize
        elide: root.elide
        font.family: root.cfg.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: root.isCurrent ? root.cfg.currentWeight : root.cfg.sideWeight
        font.italic: root.cfg.fontItalic
        font.underline: root.cfg.fontUnderline
        font.letterSpacing: root.cfg.letterSpacing
        font.capitalization: root.cfg.fontCaps
    }

    // ---- shadow (blurred when asked: that needs an offscreen pass, so only then)
    Face {
        visible: root.cfg.shadowOn && root.text !== ""
        dx: root.cfg.shadowX
        dy: root.cfg.shadowY
        color: root.cfg.shadowColor
        layer.enabled: root.cfg.shadowOn && root.cfg.shadowBlur > 0
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: 48
            blur: Math.min(1, root.cfg.shadowBlur / 24)
        }
    }

    // ---- outline: the text repeated around itself
    Repeater {
        model: root.cfg.outlineOn && root.text !== "" ? 8 : 0
        Face {
            required property int index
            color: root.cfg.outlineColor
            dx: Math.cos(index * Math.PI / 4) * root.cfg.outlineWidth
            dy: Math.sin(index * Math.PI / 4) * root.cfg.outlineWidth
        }
    }

    Face { id: face; visible: !root.gradientOn }

    // ---- colours spread over the text: a gradient seen through the text's shape
    Face { id: maskFace; color: "white"; visible: false; layer.enabled: root.isCurrent } // always on for the current line: a layer switched on later stays empty
    Rectangle {
        id: fillRect
        visible: false
        layer.enabled: root.isCurrent
        width: root.width
        height: root.height
        gradient: Gradient {
            orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: root.stops[Math.min(0, root.stops.length - 1)]?.pos ?? 0; color: root.stops[Math.min(0, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(1, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(1, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(2, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(2, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(3, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(3, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(4, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(4, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(5, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(5, root.stops.length - 1)]?.color ?? "white" }
            GradientStop { position: root.stops[Math.min(6, root.stops.length - 1)]?.pos ?? 1; color: root.stops[Math.min(6, root.stops.length - 1)]?.color ?? "white" }
        }
    }
    MultiEffect {
        visible: root.gradientOn
        anchors.fill: parent
        source: fillRect
        maskEnabled: true
        maskSource: maskFace
    }
}
