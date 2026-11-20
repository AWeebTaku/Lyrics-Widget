// The settings model (settings/model.js), the config keys (config/main.xml) and the generated page files must agree.
// Run: node tests/settings.test.js
const fs = require("fs");
const ui = __dirname + "/../plasmoid/contents/ui/";
const xml = fs.readFileSync(__dirname + "/../plasmoid/contents/config/main.xml", "utf8");
const M = new Function(fs.readFileSync(ui + "settings/model.js", "utf8").replace(".pragma library", "") + ";return {pages, pageKeys, rowKeys, whenMet, flows, flowValues}")();
let failures = 0;
function check(c, msg) { if (!c) { ++failures; console.log("FAIL", msg); } }

const entries = {};
for (const m of xml.matchAll(/<entry name="(\w+)" type="(\w+)">([\s\S]*?)<\/entry>/g))
    entries[m[1]] = { type: m[2], def: (/<default[^>]*>([^<]*)<\/default>/.exec(m[3]) || [0, ""])[1].trim() };

// which main.xml types a row type may store in
const stores = { bool: ["Bool"], int: ["Int"], real: ["Double"], color: ["String"], text: ["String"], file: ["String"], font: ["String"],
                 flow: ["Int"], palette: ["Int"], pair: ["Int"], align: ["Int"], colors: ["String"], eq: ["StringList"], source: ["String"], sites: ["String"], layoutedit: ["String"] };
const noKey = ["presets", "spotify", "queuecheck", "browser", "info"];
const seenKeys = {};
const pageFiles = { general: "configGeneral.qml", lyrics: "configLyrics.qml", visualizer: "configVisualizer.qml", audio: "configAudio.qml",
                    card: "configCard.qml", sources: "configAccounts.qml" };

function defOf(k) { return entries[k] ? entries[k].def : undefined; }
function inRange(v, lo, hi) { return +v >= lo && +v <= hi; }

for (const p of M.pages) {
    const ids = new Set();
    check(p.title && p.icon && p.subtitle, `${p.id}: needs a title, an icon and a subtitle`);
    check(p.sections.length > 0 && p.sections.filter(s => s.open).length <= 1, `${p.id}: at least one section, at most one open at the start`);
    for (const s of p.sections) {
        check(!ids.has(s.id), `${p.id}: section ${s.id} listed twice`); ids.add(s.id);
        check(s.title && s.desc, `${p.id}/${s.id}: needs a title and a description`);
        check(s.rows.length > 0, `${p.id}/${s.id}: no rows`);
        for (const r of s.rows) {
            const where = `${p.id}/${s.id}/${r.key || (r.keys || []).join("+") || r.type}`;
            check(r.type, `${where}: no type`);
            if (noKey.includes(r.type)) { check(!r.key && !r.keys, `${where}: a ${r.type} row has no key`); continue; }
            if (r.type === "pair" || r.type === "align") check(Array.isArray(r.keys) && r.keys.length === 2, `${where}: needs two keys`);
            else check(!!r.key, `${where}: no key`);
            check(r.label || r.type === "layoutedit", `${where}: no label`);
            // conventions: no unit in a label (it is in the box), no stray offText, a pair names its two boxes
            check(!/\((px|%|s|ms|Hz)\)/.test(r.label || ""), `${where}: put the unit in unit.suffix, not in the label`);
            check(r.offText === undefined, `${where}: use off, not offText`);
            if (r.type === "pair") check(Array.isArray(r.names) && r.names.length === 2 && r.unit && r.unit.suffix, `${where}: a pair needs names and a unit`);
            for (const k of M.rowKeys(r)) {
                (seenKeys[k] = seenKeys[k] || []).push(p.id);
                const e = entries[k];
                check(e, `${where}: ${k} is not in main.xml`);
                if (!e) continue;
                if (r.type === "combo") {
                    const strings = r.values && typeof r.values[0] === "string";
                    check(e.type === (strings ? "String" : "Int"), `${where}: ${k} is ${e.type} in main.xml, the combo stores ${strings ? "text" : "numbers"}`);
                    check(Array.isArray(r.options) && r.options.length >= 2, `${where}: combo needs options`);
                    if (r.values) check(r.values.length === r.options.length, `${where}: values and options differ in number`);
                    const d = strings ? e.def : +e.def;
                    check(r.values ? r.values.includes(d) : (d >= 0 && d < r.options.length), `${where}: default ${e.def} is not one of the options`);
                } else {
                    check((stores[r.type] || []).includes(e.type), `${where}: ${k} is ${e.type} in main.xml, a ${r.type} row stores ${(stores[r.type] || []).join("/")}`);
                }
                if (r.type === "int" || r.type === "pair") {
                    check(r.min < r.max, `${where}: min must be below max`);
                    check(inRange(e.def, r.min, r.max), `${where}: ${k} default ${e.def} is outside ${r.min}..${r.max}`);
                }
                if (r.type === "real") check(inRange(+e.def * r.scale, r.min, r.max), `${where}: default ${e.def} is outside the range`);
                if (r.type === "flow") check(M.flowValues.includes(+e.def), `${where}: default flow ${e.def} is not a flow`);
            }
            for (const w of [].concat(r.when || [])) {
                check(entries[w.key] !== undefined, `${where}: "when" names an unknown key ${w.key}`);
                check(w.in !== undefined || w.not !== undefined, `${where}: "when" needs in or not`);
            }
        }
    }
}
// a row's `when`: one condition, or a list that must all hold
{
    const v = { a: 1, b: true };
    const get = k => v[k];
    check(M.whenMet(undefined, get) && M.whenMet({ key: "a", in: [1] }, get) && !M.whenMet({ key: "a", in: [2] }, get), "whenMet: in");
    check(M.whenMet({ key: "a", in: "positive" }, get) && M.whenMet({ key: "a", not: [2] }, get), "whenMet: positive and not");
    check(M.whenMet([{ key: "a", in: [1] }, { key: "b", in: [true] }], get) && !M.whenMet([{ key: "a", in: [1] }, { key: "b", in: [false] }], get), "whenMet: a list needs all");
    // the shape a list takes inside QML: an object with a length, not an Array
    const like = { 0: { key: "a", in: [1] }, 1: { key: "b", in: [false] }, length: 2 };
    check(!M.whenMet(like, get) && M.whenMet({ 0: { key: "a", in: [1] }, length: 1 }, get), "whenMet: an array-like list");
}
// the preset manager's own keys belong to the Visualizer page
for (const k of ["vizUserPresets", "vizFavourites"]) (seenKeys[k] = seenKeys[k] || []).push("visualizer");

// every setting on exactly one page; only two have none
const noPage = ["showPanel", "debugMode"];   // showPanel: only read once, to move the old background setting to the card surface
for (const [k, pages] of Object.entries(seenKeys)) check(pages.length === 1, `${k} is on ${pages.length} pages: ${pages.join(", ")}`);
for (const k of Object.keys(entries)) check(seenKeys[k] || noPage.includes(k), `${k} is in main.xml but no page has it`);

// the generated pages declare exactly their model's keys (and the Default twins), and nothing else does
const declared = {};
for (const f of fs.readdirSync(ui).filter(f => /^config.*\.qml$/.test(f)))
    for (const m of fs.readFileSync(ui + f, "utf8").matchAll(/property \w+ cfg_(\w+?)(Default)?\s*\n/g))
        (declared[f] = declared[f] || { keys: new Set(), twins: new Set() })[m[2] ? "twins" : "keys"].add(m[1]);
for (const p of M.pages) {
    const f = pageFiles[p.id], src = fs.readFileSync(ui + f, "utf8"), d = declared[f] || { keys: new Set(), twins: new Set() };
    const want = new Set(M.pageKeys(p));
    check(/GENERATED by tools\/gen-settings\.js/.test(src), `${f} is not a generated page (run node tools/gen-settings.js)`);
    check(src.includes(`pageId: "${p.id}"`), `${f} does not show the ${p.id} page`);
    for (const k of want) { check(d.keys.has(k), `${f} does not declare cfg_${k} (run node tools/gen-settings.js)`); check(d.twins.has(k), `${f} does not declare cfg_${k}Default`); }
    for (const k of d.keys) check(want.has(k), `${f} declares cfg_${k}, which is not on its model page`);
}
for (const f of Object.keys(declared)) check(Object.values(pageFiles).includes(f), `${f} declares settings but is not a generated page`);
check(!fs.existsSync(ui + "configLibrary.qml") || !declared["configLibrary.qml"], "configLibrary.qml must not declare cfg_ values");

// the stand-alone settings window's panels: generated, and declaring exactly the keys of their model page (and defaults)
for (const p of M.pages) {
    const f = p.id[0].toUpperCase() + p.id.slice(1) + "Panel.qml", src = fs.readFileSync(ui + "settings/" + f, "utf8");
    check(/GENERATED by tools\/gen-settings\.js/.test(src), `settings/${f} is not generated (run node tools/gen-settings.js)`);
    const decl = new Set([...src.matchAll(/property \w+ cfg_(\w+?)(Default)?\s*\n/g)].filter(m => !m[2]).map(m => m[1]));
    const want = new Set(M.pageKeys(p));
    for (const k of want) check(decl.has(k), `settings/${f} does not declare cfg_${k} (run node tools/gen-settings.js)`);
    for (const k of decl) check(want.has(k), `settings/${f} declares cfg_${k}, which is not on its model page`);
    const def = JSON.parse(/readonly property var defaults: \((.*)\)\n/.exec(src)[1]);
    for (const k of want) check(def[k] !== undefined && (typeof def[k] === "boolean" ? String(def[k]) === entries[k].def : typeof def[k] === "number" ? def[k] === Number(entries[k].def || 0) : true), `settings/${f}: default of ${k} differs from main.xml`);
}
check(fs.existsSync(ui + "SettingsWindow.qml"), "SettingsWindow.qml is missing");
// every window of the widget asks KWin to center it (a window cannot place itself on Wayland)
check(fs.existsSync(ui + "../kwin/center.js"), "kwin/center.js is missing");
for (const f of ["SettingsWindow.qml", "LibraryWindow.qml"]) {
    const w = fs.readFileSync(ui + f, "utf8");
    check(/WindowPlacer/.test(w) && /kwin\/center\.js/.test(w), `${f} must ask KWin to center it`);
}
check(/src\/WindowPlacer\.cpp/.test(fs.readFileSync(__dirname + "/../CMakeLists.txt", "utf8")), "CMakeLists.txt must build WindowPlacer");
const mainQml = fs.readFileSync(ui + "main.qml", "utf8");
check(/SettingsWindow\.qml/.test(mainQml) && /contextualActions/.test(mainQml), "main.qml must open the widget's own settings window from the menu");
check(/removeInternalAction\("configure"\)/.test(mainQml) && /Configure %1/.test(mainQml), "the menu has one Configure entry: Plasma's own is replaced by the widget's, not joined by a second");

// the files the renderer needs exist, and the old settings code is gone
for (const f of ["SettingsPage", "Section", "Field", "LayoutEditor", "ColorSwatch", "AlignPicker", "EqEditor", "ColorSpec", "PresetsPanel", "SourceField", "SpotifyCheck", "BrowserSetupRow", "SitesList"])
    check(fs.existsSync(ui + "settings/" + f + ".qml"), `settings/${f}.qml is missing`);
for (const f of ["card/SchemaForm.qml", "card/schema.js", "PageHeader.qml", "PillTab.qml", "PillTabBar.qml", "PanelStack.qml", "LazyTab.qml", "audioviz/ConfigVisualizer.qml", "audioviz/ConfigCava.qml"])
    check(!fs.existsSync(ui + f), `${f} is old settings code and should be gone`);
const config = fs.readFileSync(ui + "../config/config.qml", "utf8");
for (const f of [...Object.values(pageFiles), "configLibrary.qml"]) check(config.includes(`"${f}"`), `config.qml does not list ${f}`);

// a file that uses `Plasmoid.` must import it (the offscreen test pages stub it out, so only this check catches a missing import)
for (const f of fs.readdirSync(ui + "settings").filter(f => f.endsWith(".qml"))) {
    const src = fs.readFileSync(ui + "settings/" + f, "utf8");
    if (/\bPlasmoid\./.test(src)) check(/import org\.kde\.plasma\.plasmoid/.test(src), `settings/${f} uses Plasmoid but does not import org.kde.plasma.plasmoid`);
}

// one spelling (American) in what the user reads
const model = fs.readFileSync(ui + "settings/model.js", "utf8").replace(/vizFavourites/g, "");
for (const bad of [/colour/i, /centre/i, /favourite/i, /behaviour/i, /\bgrey\b/i, /organis/i]) check(!bad.test(model), `model.js uses the British spelling ${bad}`);

// preset keys exist in main.xml with the right kind
const P = new Function(fs.readFileSync(ui + "viz/presets.js", "utf8").replace(".pragma library", "") + ";return {keys}")();
for (const [k, spec] of Object.entries(P.keys)) {
    const e = entries[k];
    check(e, `preset key ${k} is not in main.xml`);
    if (e) check((spec.type === "boolean" && e.type === "Bool") || (spec.type === "number" && e.type === "Int") || (spec.type === "string" && e.type === "String"), `preset key ${k}: type differs from main.xml`);
    if (e && spec.type === "number") check(+e.def === spec.def, `preset key ${k}: default ${spec.def} differs from main.xml ${e.def}`);
    if (e && spec.type === "boolean") check((e.def === "true") === spec.def, `preset key ${k}: boolean default differs`);
}
if (failures) process.exit(1);
console.log("settings: ok");
