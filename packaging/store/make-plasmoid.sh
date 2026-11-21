#!/usr/bin/env bash
# Packs the widget for the KDE Store: build/org.lyricwidget-<version>.plasmoid (a zip of the plasmoid folder).
# It only reads the source and writes into build/. The store hosts the QML part only: the C++ plugin has to be
# installed on the user's system (./install.sh in the repository does that), so say so on the store page.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
ver="$(python3 -c "import json;print(json.load(open('$root/plasmoid/metadata.json'))['KPlugin']['Version'])")"
out="$root/build/org.lyricwidget-$ver.plasmoid"
mkdir -p "$root/build"; rm -f "$out"
(cd "$root/plasmoid" && zip -qr "$out" . -x '*.DS_Store')
echo "wrote $out ($(du -h "$out" | cut -f1))"
unzip -l "$out" | tail -1
