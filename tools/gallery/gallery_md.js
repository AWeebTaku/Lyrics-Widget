// Prints docs/gallery.md from the built-in looks (the pictures are made by render.sh)
const fs = require("fs");
const src = fs.readFileSync(__dirname + "/../../plasmoid/contents/ui/viz/presets.js", "utf8").replace(".pragma library", "");
const P = new Function(src + ";return {builtin}")();
const sections = [["Visualizer looks", 0, 16], ["Cards, posters, orbits and strips", 16, P.builtin.length]];
let out = "# Preset gallery\n\nEvery built-in look, drawn by the widget's own code with a sample song and a made-up spectrum. Apply one in\n**Settings, Looks**. Made by `tools/gallery/render.sh`.\n";
for (const [title, a, b] of sections) {
    out += `\n## ${title}\n`;
    for (let i = a; i < b; ++i) {
        const p = P.builtin[i];
        out += `\n### ${p.name}\n\n${p.about}\n\n![${p.name}](gallery/${String(i).padStart(2, "0")}.png)\n`;
    }
}
process.stdout.write(out);
