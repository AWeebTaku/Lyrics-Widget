.pragma library
// One width for the settings window and the lyrics library window, in Kirigami grid units.
// The shell opens the settings window at 45 (its content item asks for that width, and the window follows it), so a page
// asks for more: it raises the content item's implicit width as well as the window's. Never shrinks a wider window.
const units = 62
function grow(win, gridUnit) {
    if (!win)
        return
    const want = gridUnit * units
    const root = win.contentItem && win.contentItem.children.length > 0 ? win.contentItem.children[0] : null
    if (root && root.implicitWidth < want)
        root.implicitWidth = want
    if (win.width < want)
        win.width = want
}
