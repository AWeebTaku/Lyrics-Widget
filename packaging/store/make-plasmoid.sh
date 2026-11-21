#!/usr/bin/env bash
# Packs the widget for the KDE Store: build/org.lyricwidget-<version>.plasmoid (a zip of the plasmoid folder).
# The store hosts QML only and cannot build the C++ plugin, so the package also carries the plugin's source and the installer
# (contents/installer/): when the plugin is missing, the widget's setup screen runs that installer with that source, with no
# download, and the plugin it builds is always the same version as the widget. It only reads the repository and writes into build/.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
ver="$(python3 -c "import json;print(json.load(open('$root/plasmoid/metadata.json'))['KPlugin']['Version'])")"
out="$root/build/org.lyricwidget-$ver.plasmoid"
stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
mkdir -p "$root/build"; rm -f "$out"

cp -r "$root/plasmoid/." "$stage/"
inst="$stage/contents/installer"; src="$inst/source"
mkdir -p "$src/docs" "$src/tools"
cp "$root/CMakeLists.txt" "$root/setup-romaji.sh" "$src/"
cp -r "$root/src" "$root/romaji" "$root/examples" "$root/extension" "$src/"
cp "$root/tools/doctor.sh" "$src/tools/"
cp "$root/docs/favicon.svg" "$src/docs/"
cp "$root/packaging/release/lyric-widget.sh" "$inst/"

(cd "$stage" && zip -qr "$out" . -x '*.DS_Store')
echo "wrote $out ($(du -h "$out" | cut -f1))"
unzip -l "$out" | tail -1
