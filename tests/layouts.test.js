// Checks for plasmoid/contents/ui/card/layouts.js. Run: node tests/layouts.test.js
const fs = require("fs");
const src = fs.readFileSync(__dirname + "/../plasmoid/contents/ui/card/layouts.js", "utf8").replace(".pragma library", "");
const L = new Function(src + ";return {modes, layout, luminance, naturalSize, needsResize, minSize, sizeText, partsFor, setEdit, getEdit, resetEdits, editsFor, vizBase}")();
let failures = 0;
function check(c, msg) { if (!c) { ++failures; console.log("FAIL", msg); } }
const inside = (r, W, H) => !r || (r.x >= 0 && r.y >= 0 && r.w >= 0 && r.h >= 0 && r.x + r.w <= W && r.y + r.h <= H);
const overlap = (a, b) => a && b && a.w > 0 && a.h > 0 && b.w > 0 && b.h > 0 && a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

check(L.modes.length === 12 && L.modes.every((m, i) => m.id === i), "modes are numbered 0..11");
check(L.modes.every(m => L.naturalSize(m.id).length === 2 && L.naturalSize(m.id)[0] > 0), "every layout has a natural size");
// lyrics only is today's widget: lyrics fill everything, no card parts
const l0 = L.layout(0, 480, 200, 96);
check(l0.lyrics.w === 480 && l0.lyrics.h === 200 && !l0.art && !l0.info && !l0.controls && !l0.progress, "mode 0 untouched");
check(L.layout(1, 480, 200, 96).vizFill && L.layout(1, 480, 200, 96).lyrics === null, "visualizer only");
// every part stays inside the widget, and the main parts do not sit on top of each other, for a range of sizes
for (const [W, H] of [[360, 160], [480, 200], [640, 260], [420, 380], [300, 120], [800, 90]]) {
    for (const m of L.modes) {
        const o = L.layout(m.id, W, H, 96);
        for (const k of ["art", "info", "controls", "progress", "lyrics", "clock", "vizRect"])
            check(inside(o[k], W, H), `mode ${m.id} ${W}x${H}: ${k} inside`);
        if (m.id === 2 || m.id === 3 || m.id === 6 || m.id === 10) {
            for (const [a, b] of [["info", "controls"], ["info", "progress"], ["controls", "progress"], ["art", "info"], ["art", "controls"], ["lyrics", "progress"], ["lyrics", "controls"]])
                if (H >= 200 && W >= 360) check(!overlap(o[a], o[b]), `mode ${m.id} ${W}x${H}: ${a} and ${b} do not overlap`);
        }
    }
}
// art never exceeds the setting or the widget
check(L.layout(2, 480, 200, 400).art.w <= 200 - 28, "art is capped by the height");
check(L.layout(2, 480, 200, 20).art.w === 32, "art has a minimum");
// orbit has a ring rect that contains the art
const o7 = L.layout(7, 400, 400, 96);
check(o7.orbit && o7.vizRect && o7.art.x >= o7.vizRect.x && o7.art.x + o7.art.w <= o7.vizRect.x + o7.vizRect.w, "orbit art sits inside the ring");
// luminance: light and dark colours, Qt's alpha-first form, and not-a-colour
check(L.luminance("#ffffff").lum > 0.99 && L.luminance("#000000").lum < 0.01 && L.luminance("#ffffff").alpha === 1, "luminance of white and black");
const lt = L.luminance("#80f0f0f0");
check(Math.abs(lt.alpha - 128 / 255) < 1e-6 && lt.lum > 0.8, "alpha comes first in #aarrggbb");
check(L.luminance("#cc1c2030").lum < 0.05 && L.luminance("red") === null && L.luminance("") === null, "dark colour and bad input");
// at its natural size every layout fits and shows what it should
for (const m of L.modes) {
    const [nw, nh] = L.naturalSize(m.id), o = L.layout(m.id, nw, nh, 96);
    for (const k of ["art", "info", "controls", "progress", "lyrics", "clock", "vizRect"]) check(inside(o[k], nw, nh), `mode ${m.id} natural size: ${k} inside`);
    if (m.id >= 2 && m.id !== 1 && m.id !== 8 && m.id !== 11) check(o.info || o.art, `mode ${m.id} shows something at its natural size`);
}
// the icon is only the cover with a ring; the poster honours its options
const ic = L.layout(11, 64, 64, 96);
check(ic.ring && ic.art && ic.art.w >= 48 && !ic.info && !ic.controls && ic.lyrics === null, "icon layout");
check(L.layout(8, 440, 220, 96, 14, { posterClock: false }).clock === null && L.layout(8, 440, 220, 96, 14, { posterLines: 1 }).info.h < L.layout(8, 440, 220, 96, 14, { posterLines: 2 }).info.h, "poster options");
// orbit with the title inside: the cover is smaller and sits above the title
const oa = L.layout(7, 340, 380, 96), ob = L.layout(7, 340, 380, 96, 14, { orbitCenter: 1 });
check(ob.art.w < oa.art.w && ob.art.y < oa.art.y, "orbit with the title in the middle makes room for it");
// hover buttons and the sync row: placed by the layout, inside the card, and clear of the card's own buttons and seek bar
for (const m of L.modes.filter(m => m.id >= 2 && m.id !== 11)) {
    const [W, H] = L.naturalSize(m.id);
    const o = L.layout(m.id, W, H, 96, 14, {});
    if (!o.tools) continue;
    check(inside(o.tools, W, H) && inside(o.nudge, W, H), `${m.name}: hover buttons and sync row inside the card`);
    check(!overlap(o.tools, o.controls) && !overlap(o.tools, o.progress), `${m.name}: hover buttons clear of the card's buttons and seek bar`);
    check(!overlap(o.nudge, o.progress), `${m.name}: sync row clear of the seek bar`);
}
check(L.layout(11, 64, 64, 96, 14, {}).tools === null, "icon layout has no lyric hover buttons");
// which arrangements need a resize
check(!L.needsResize(0, 100, 50) && !L.needsResize(1, 100, 50), "lyrics only and visualizer only never need a resize");
check(L.needsResize(8, 760, 100) && L.needsResize(7, 760, 100), "poster and orbit need more than a 100 px high widget");
check(!L.needsResize(9, 760, 100) && !L.needsResize(4, 760, 100), "slim strip and inline fit a 100 px high widget");
check(!L.needsResize(8, 0, 0), "a free widget is never too small");

// ---- editing a layout: hide, move, resize, see-through, per layout
{
    const base = L.layout(2, 420, 160, 96, 14, {});
    let e = L.setEdit("{}", 2, "art", "dx", 30);
    e = L.setEdit(e, 2, "art", "dw", -20);
    e = L.setEdit(e, 2, "controls", "show", false);
    e = L.setEdit(e, 2, "info", "opacity", 50);
    e = L.setEdit(e, 2, "info", "size", 22);
    const o = L.layout(2, 420, 160, 96, 14, { edits: e });
    check(o.art.x === base.art.x + 30 && o.art.w === base.art.w - 20 && o.art.y === base.art.y, "an edit moves and resizes a part by the difference");
    check(o.controls === null && o.hidden.controls === true, "an edit can hide a part");
    check(o.opacity.info === 0.5 && o.infoSize === 22, "opacity and the title size are edits");
    check(JSON.stringify(o.progress) === JSON.stringify(base.progress), "parts without an edit are untouched");
    // the same edits follow the card when it is resized, and other layouts are not affected
    const big = L.layout(2, 840, 320, 96, 14, { edits: e }), bigBase = L.layout(2, 840, 320, 96, 14, {});
    check(big.art.x === bigBase.art.x + 30, "edits are differences, so they follow a resized card");
    check(JSON.stringify(L.layout(3, 420, 160, 96, 14, { edits: e }).art) === JSON.stringify(L.layout(3, 420, 160, 96, 14, {}).art), "edits of one layout do not touch another");
    // a size never goes below 8 px
    check(L.layout(2, 420, 160, 96, 14, { edits: L.setEdit("{}", 2, "art", "dw", -500) }).art.w === 8, "a part cannot be made smaller than 8 px");
    // the background is a part of the card: whole widget by default, editable
    check(JSON.stringify(base.surface) === JSON.stringify({ x: 0, y: 0, w: 420, h: 160 }), "the background covers the card");
    check(L.layout(2, 420, 160, 96, 14, { edits: L.setEdit("{}", 2, "surface", "dx", 10) }).surface.x === 10, "the background can be moved");
    check(L.layout(2, 420, 160, 96, 14, { edits: L.setEdit("{}", 2, "surface", "show", false) }).surface === null, "the background can be hidden");
    // the corner buttons and the sync row: hidden or moved like the rest, and shown even where the layout has no room for them
    check(L.layout(2, 420, 160, 96, 14, { edits: L.setEdit("{}", 2, "tools", "show", false) }).tools === null, "the corner buttons can be hidden");
    const icon = L.layout(11, 64, 64, 96, 14, {});
    check(icon.tools === null, "the icon layout has no corner buttons by itself");
    check(L.layout(11, 64, 64, 96, 14, { edits: L.setEdit("{}", 11, "tools", "show", true) }).tools !== null, "...but they can be turned on");
    // layout 1 (visualizer only) uses layout 0's edits (no card)
    check(L.layout(1, 480, 200, 96, 14, { edits: L.setEdit("{}", 0, "viz", "dx", 15) }).vizPlace.x === 15, "layouts 0 and 1 share their edits");
    // where the visualizer goes when the layout does not place it
    const v = { widthPct: 50, heightPct: 40, hAlign: 2, vAlign: 0, offX: -5, offY: 7 };
    const z = L.layout(0, 400, 200, 96, 14, { viz: v });
    check(z.vizPlace.w === 200 && z.vizPlace.h === 80 && z.vizPlace.x === 195 && z.vizPlace.y === 7, "the visualizer's own position (width, height, place, offset)");
    check(L.layout(5, 440, 200, 96, 14, {}).vizPlace.w === 440, "a layout that fills the card with the music gives it the whole card");
    // bad or empty stored text is ignored; a field at its default is dropped; reset
    check(L.layout(2, 420, 160, 96, 14, { edits: "not json" }).art.x === base.art.x, "unreadable edits are ignored");
    check(L.setEdit(L.setEdit("{}", 2, "art", "dx", 5), 2, "art", "dx", 0) === "{}", "an edit set back to its default is dropped");
    check(L.setEdit(L.setEdit("{}", 2, "art", "show", false), 2, "art", "show", undefined) === "{}", "undefined clears a field");
    check(L.resetEdits(L.setEdit(L.setEdit("{}", 2, "art", "dx", 5), 3, "art", "dx", 5), 2) === '{"3":{"art":{"dx":5}}}', "reset one layout");
    check(L.resetEdits("{\"2\":{}}") === "{}", "reset everything");
    // the cover and the progress ring can be hidden separately; hiding the cover keeps its place (the ring is drawn there)
    const ic = L.layout(11, 64, 64, 96, 14, {});
    const noCover = L.layout(11, 64, 64, 96, 14, { edits: L.setEdit("{}", 11, "art", "show", false) });
    check(noCover.hidden.art === true && JSON.stringify(noCover.art) === JSON.stringify(ic.art) && !noCover.hidden.ring, "the icon: hide the cover, keep its place and the ring");
    const noRing = L.layout(11, 64, 64, 96, 14, { edits: L.setEdit("{}", 11, "ring", "show", false) });
    check(noRing.hidden.ring === true && !noRing.hidden.art && noRing.art !== null, "the icon: hide the ring, keep the cover");
    check(L.layout(2, 420, 160, 96, 14, { edits: L.setEdit("{}", 2, "ring", "show", false) }).art !== null, "a ring edit does not touch another layout's cover");
    // every layout can hide every part it has, one by one (the others stay), and all together
    for (const m of [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
        const ps = L.partsFor(m).map(p => p.id);
        const [w, h] = m === 0 ? [760, 220] : L.naturalSize(m);
        const base = L.layout(m, w, h, 96, 14, {});
        for (const id of ps) {
            const o = L.layout(m, w, h, 96, 14, { edits: L.setEdit("{}", m, id, "show", false) });
            check(o.hidden[id] === true, `layout ${m}: ${id} can be hidden`);
            for (const other of ps.filter(x => x !== id && x !== "ring" && x !== "viz")) {
                const key = L.partsFor(m).find(p => p.id === other).key;
                check(JSON.stringify(o[key]) === JSON.stringify(base[key]), `layout ${m}: hiding ${id} leaves ${other} alone`);
            }
        }
        let all = "{}";
        for (const id of ps) all = L.setEdit(all, m, id, "show", false);
        const none = L.layout(m, w, h, 96, 14, { edits: all });
        check(none.lyrics === null && none.controls === null && none.progress === null && none.info === null && none.clock === null && none.surface === null && none.tools === null && none.nudge === null, `layout ${m}: everything can be hidden at once`);
    }
    // which parts a layout offers
    check(L.partsFor(11).map(p => p.id).join() === "surface,art,ring,viz,tools,nudge", "the icon offers its cover and its progress ring as separate parts");
    check(L.partsFor(2).some(p => p.id === "controls") && L.partsFor(2).some(p => p.id === "lyrics"), "classic offers its buttons and its lyrics");
    check(L.partsFor(8).some(p => p.id === "clock"), "poster offers its clock");
}

if (failures) process.exit(1);
console.log("layouts: ok");

