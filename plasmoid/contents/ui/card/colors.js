.pragma library
// Which color a part of the card uses. source: 0 the card's accent, 1 the text color, 2 the Plasma accent, 3 a color
// of the user's own. (The card accent itself has its own list: 0 cover colors, 1 Plasma accent, 2 a color of its own.)
function pick(source, accent, text, plasma, custom) {
    return source === 1 ? text : source === 2 ? plasma : source === 3 ? custom : accent
}
function accent(source, cover, plasma, custom) {
    return source === 1 ? plasma : source === 2 ? custom : cover
}
