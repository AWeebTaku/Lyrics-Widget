// Checks for plasmoid/contents/ui/card/layouts.js. Run: node tests/layouts.test.js
const fs = require("fs");
const src = fs.readFileSync(__dirname + "/../plasmoid/contents/ui/card/layouts.js", "utf8").replace(".pragma library", "");
const L = new Function(src + ";return {modes, layout, luminance, naturalSize, needsResize, minSize, sizeText}")();
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

if (failures) process.exit(1);
console.log("layouts: ok");

