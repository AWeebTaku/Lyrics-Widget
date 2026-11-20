// Checks for plasmoid/contents/ui/viz/presets.js (pure functions). Run: node tests/presets.test.js
const fs = require("fs");
const src = fs.readFileSync(__dirname + "/../plasmoid/contents/ui/viz/presets.js", "utf8").replace(".pragma library", "");
const P = new Function(src + ";return {keys, defaults, complete, builtin, parseUser, saveUser, deleteUser, exportText, importText, randomPick, dailyPick, all, toggleFav, parseFav}")();
let failures = 0;
function check(c, msg) { if (!c) { ++failures; console.log("FAIL", msg); } }

// complete(): unknown keys dropped, bad types and out-of-range values fall back to the default
const c = P.complete({ visualizerStyle: 5, barWidth: "wide", vizGlow: 999, bogus: 1, vizTaper: true, vizSmoothing: 40.6 });
check(c.visualizerStyle === 5 && c.barWidth === P.keys.barWidth.def && c.vizGlow === 0 && c.bogus === undefined && c.vizTaper === true && c.vizSmoothing === 41, "complete");
check(Object.keys(P.complete(null)).length === Object.keys(P.keys).length, "complete(null) has every key");
// built-ins are complete and valid
check(P.builtin.length >= 28 && P.builtin.every(p => p.builtin && Object.keys(p.settings).length === Object.keys(P.keys).length), "built-in presets complete");
check(new Set(P.builtin.map(p => p.name)).size === P.builtin.length, "built-in names unique");
check(P.builtin.every(p => typeof p.about === "string" && p.about.length > 10), "every built-in look has a description");
// user presets: save, replace by name, delete, survive bad stored text
let u = "[]";
u = P.saveUser(u, "Mine", { visualizerStyle: 9 });
u = P.saveUser(u, "Mine", { visualizerStyle: 3 });
u = P.saveUser(u, "Other", {});
check(P.parseUser(u).length === 2 && P.parseUser(u).find(p => p.name === "Mine").settings.visualizerStyle === 3, "save replaces by name");
check(P.parseUser(P.deleteUser(u, "Mine")).length === 1, "delete");
check(P.parseUser("not json").length === 0 && P.parseUser('{"a":1}').length === 0, "bad stored text");
check(P.saveUser("[]", "   ", {}) === "[]", "empty name is not saved");
// export / import round trip, and bad input is rejected
const round = P.importText(P.exportText(P.builtin[2]));
check(round.ok && round.preset.name === P.builtin[2].name && JSON.stringify(round.preset.settings) === JSON.stringify(P.builtin[2].settings), "round trip");
check(!P.importText("hello").ok && !P.importText("{}").ok && !P.importText('{"format":2,"settings":{}}').ok && !P.importText('{"format":1}').ok, "bad import rejected");
check(P.importText('{"format":1,"settings":{"visualizerStyle":"x","vizGlow":-5}}').preset.settings.vizGlow === 0, "import sanitises values");
// random never repeats the current one; daily is stable
check(P.randomPick(P.builtin, "Calm", 0.99).name !== "Calm" && P.randomPick(P.builtin, P.builtin[0].name, 0).name !== P.builtin[0].name, "random avoids current");
check(P.dailyPick(P.builtin, "2026-11-18").name === P.dailyPick(P.builtin, "2026-11-18").name, "daily is stable");
// favourites sort first and toggle; a bad surface colour is replaced by the default
let fav = P.toggleFav("[]", "Calm");
check(P.all("[]", fav)[0].name === "Calm" && P.all("[]", fav)[0].fav, "favourite sorts first");
check(P.parseFav(P.toggleFav(fav, "Calm")).length === 0 && P.parseFav("nonsense").length === 0, "favourite toggles off, bad stored text");
check(P.complete({ panelColor: "red" }).panelColor === P.keys.panelColor.def && P.complete({ panelColor: "#11223344" }).panelColor === "#11223344", "surface colour is validated");
check(P.builtin.every(p => p.settings.layoutMode >= 2 && p.settings.layoutMode <= 11), "layouts in range");
check(P.builtin.filter(p => p.settings.showCard).length >= 20 && P.builtin.filter(p => !p.settings.showLyrics).length === 4, "card looks turn the card on; the four visualizer-only looks turn the lyrics off");
if (failures) process.exit(1);
console.log("presets: ok");
