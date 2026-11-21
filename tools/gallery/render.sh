#!/usr/bin/env bash
# Renders docs/gallery/*.png (one picture per built-in look) and writes docs/gallery.md.
# It uses the widget's own QML with a stand-in for the settings, a sample song and a made-up spectrum, on your display
# (the GPU styles and glass need one). Needs: Qt6 development files, g++, python3, node, and a build of the backend
# (cmake -B build -S . && cmake --build build).   Usage: tools/gallery/render.sh [build dir]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(cd "$here/../.." && pwd)"
build="${1:-$root/build}"
[ -f "$build/org/lyricwidget/liblyricbackend.so" ] || { echo "build the backend first: cmake -B build -S . && cmake --build build"; exit 1; }
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
python3 - "$root" "$work" <<'PY'
import os, shutil, json, sys, xml.etree.ElementTree as ET
root, work = sys.argv[1], sys.argv[2]
src = root + "/plasmoid/contents/ui"; dest = work + "/ui"
shutil.copytree(src, dest)
props = []
ns = "{http://www.kde.org/standards/kcfg/1.0}"
for e in ET.parse(root + "/plasmoid/contents/config/main.xml").getroot().iter(ns + "entry"):
    name, typ = e.get("name"), e.get("type")
    d = e.find(ns + "default"); dv = (d.text or "").strip() if d is not None else ""
    if typ == "Int": props.append(f"    property int {name}: {int(dv or 0)}")
    elif typ == "Bool": props.append(f"    property bool {name}: {'true' if dv == 'true' else 'false'}")
    elif typ == "Double": props.append(f"    property real {name}: {float(dv or 0)}")
    else: props.append(f"    property string {name}: {json.dumps(dv)}")
open(dest + "/Cfg.qml", "w").write("pragma Singleton\nimport QtQuick\nQtObject {\n" + "\n".join(props) + "\n    function writeConfig() {}\n}\n")
open(dest + "/qmldir", "w").write("singleton Cfg 1.0 Cfg.qml\n")
for r, _, files in os.walk(dest):
    for f in files:
        if f.endswith(".qml") and f != "Cfg.qml":
            p = os.path.join(r, f); s = open(p).read()
            if "Plasmoid.configuration" in s:
                s = s.replace("Plasmoid.configuration", "Cfg")
                if r != dest: s = s.replace("import org.kde.plasma.plasmoid", "import org.kde.plasma.plasmoid\nimport \"file://" + dest + "\"")
                open(p, "w").write(s)
shutil.copy(root + "/tools/gallery/gallery.qml", work + "/gallery.qml")
s = open(work + "/gallery.qml").read().replace("@UI@", dest); open(work + "/gallery.qml", "w").write(s)
PY
g++ -std=c++20 -fPIC "$here/main.cpp" -o "$work/gallery" $(pkg-config --cflags --libs Qt6Quick Qt6Gui Qt6Qml Qt6Core)
mkdir -p "$root/docs/gallery"; rm -f "$root"/docs/gallery/*.png
QT_SCALE_FACTOR="${SCALE:-1.5}" QML2_IMPORT_PATH="$build" "$work/gallery" "$work" "$build" "$root/docs/gallery"
node "$here/gallery_md.js" > "$root/docs/gallery.md"
# the settings window shows the same pictures: keep its copies in step
mkdir -p "$root/plasmoid/contents/ui/viz/looks"
cp "$root"/docs/gallery/*.png "$root/plasmoid/contents/ui/viz/looks/"
echo "wrote $(ls "$root"/docs/gallery/*.png | wc -l) pictures and docs/gallery.md"
