.pragma library
// The look of every settings page, in one place (the page, the sections, the rows, the editors, the settings window and the
// lyrics library page all read from here, so they match):
//  - Color: only the Plasma theme (text, background and the one accent, the highlight color), so light and dark both work.
//    Every tint is the text color at a low alpha. No custom hues, no gradients.
//  - Shape: one radius scale. `radius` for containers and inputs, `radiusSmall` for small cells. Nothing else (no pills).
//  - Surfaces: sections are separated by a hairline, not boxed. A quiet plate (`plate`) only holds a group of controls that
//    belong together (an editor's parts, a banner).
//  - Type: the page title, a section title, the normal label, and small helper text that stays readable (`muted`).
//  - Width: the content is a column of `maxUnits` grid units, centered, however wide the window is.
const radius = 8
const radiusSmall = 4
const hairline = 0.12       // alpha of the text color for a 1 px rule or border
const plate = 0.045         // alpha of the text color for a quiet surface
const plateHover = 0.08
const muted = 0.75          // helper text: readable (above 4.5:1 on the theme's background), but quieter than a label
const maxUnits = 46         // grid units
const labelUnits = 13       // the name column of a row
const titleScale = 1.5
const sectionScale = 1.12
const smallScale = 0.9
