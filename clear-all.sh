#!/usr/bin/env bash
# Removes the Lyric Widget from this computer, as if it had never been installed:
#   - the widget from your desktop/panels (and its saved settings),
#   - the installed files in /usr (asks for sudo),
#   - the lyrics cache, per-song sync offsets, Spotify tokens and other cached data,
#   - the build output in this folder.
# The source code in this folder is kept.
#
#   ./clear-all.sh              asks for confirmation
#   ./clear-all.sh -y           no confirmation
#   ./clear-all.sh --dry-run    only prints what it would do
set -u
cd "$(dirname "$0")"

DRY=0
YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        -y | --yes) YES=1 ;;
        *) echo "usage: $0 [--dry-run] [-y]"; exit 2 ;;
    esac
done

run() { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }

echo "This will remove the Lyric Widget from your system:"
echo "  - the widget on your desktop and its settings"
echo "  - /usr/lib/qt6/qml/org/lyricwidget, /usr/share/plasma/plasmoids/org.lyricwidget, /usr/share/lyric-widget"
echo "  - ~/.local/share/plasmashell/lyrics.db (cache, your per-song sync adjustments AND your lyrics library), an old spotify.json"
echo "  - ~/.cache/lyric-widget and plasmashell's QML cache"
echo "  - ./build"
if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
    read -r -p "Continue? (Y/N) " answer
    case "${answer,,}" in
        y | yes) ;;
        *) echo "Cancelled."; exit 1 ;;   # n, no, or anything else
    esac
fi

echo
echo "== 1/5 remove the widget from the desktop and panels"
JS='var n = 0;
desktops().concat(panels()).forEach(function (c) {
  c.widgetIds.forEach(function (id) {
    var w = c.widgetById(id);
    if (w.type == "org.lyricwidget") { w.remove(); n++; }
  });
});
print("removed " + n + " widget(s)");'
if command -v qdbus6 > /dev/null && qdbus6 org.kde.plasmashell /PlasmaShell > /dev/null 2>&1; then
    if [ "$DRY" = 1 ]; then echo "+ qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript <remove org.lyricwidget widgets>"
    else qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS"; fi
else
    echo "plasmashell is not reachable: remove the widget by hand (right-click it, Remove)."
fi

echo
echo "== 2/5 installed files (needs sudo)"
run sudo rm -rf -- /usr/lib/qt6/qml/org/lyricwidget /usr/share/plasma/plasmoids/org.lyricwidget /usr/share/lyric-widget

echo
echo "== 3/5 cache and data"
run rm -f -- "$HOME/.local/share/plasmashell/lyrics.db" "$HOME/.local/share/plasmashell/lyrics.db-wal" \
    "$HOME/.local/share/plasmashell/lyrics.db-shm" "$HOME/.local/share/plasmashell/spotify.json"
run rm -rf -- "$HOME/.cache/lyric-widget" "$HOME/.local/share/lyric-widget" "$HOME/.cache/plasmashell/qmlcache"

echo
echo "== 4/5 build output"
run rm -rf -- ./build

echo
echo "== 5/5 restart plasmashell"
run systemctl --user restart plasma-plasmashell

echo
if [ "$DRY" = 1 ]; then echo "Dry run: nothing was changed."; else echo "Done."; fi
echo "Not done by this script:"
echo "  - remove the Chrome extension: chrome://extensions, 'Lyric Widget queue bridge', Remove"
echo "  - optional: sudo pacman -Rns kakasi   (installed only for this widget)"
echo "  - the source in $(pwd) is kept; delete the folder yourself if you want it gone"
