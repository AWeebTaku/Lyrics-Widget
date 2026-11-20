// Run by the widget (src/WindowPlacer.cpp) right after it opens one of its windows: centers the window that was just opened
// (the active one, when it is a Lyric Widget window) on the whole screen it is on, not just on the area the panels leave free.
var w = workspace.activeWindow;
if (w && /^Lyric Widget/.test(w.caption) && w.output) {
    var g = w.frameGeometry, a = w.output.geometry;
    w.frameGeometry = Qt.rect(a.x + Math.round((a.width - g.width) / 2), a.y + Math.round((a.height - g.height) / 2), g.width, g.height);
}
