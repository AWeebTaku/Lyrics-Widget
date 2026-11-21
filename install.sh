#!/usr/bin/env bash
# Installs what the widget needs besides its own QML files: the C++ plugin (org.lyricwidget), the romanization helper,
# the icon, the browser extension and the examples. Use it after installing the widget from the KDE Store (the Store
# carries the QML part only), or instead of the Store. It does not touch the widget files themselves.
#
#   ./install.sh              build and install (asks for sudo for the install step)
#   ./install.sh --dry-run    only print what it would do
#
# Packages are installed for you on Arch Linux (the tested system). On other systems it checks the tools and tells you what
# is missing; the package names differ between distributions.
set -euo pipefail

DRY=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        *) echo "usage: $0 [--dry-run]"; exit 2 ;;
    esac
done
run() { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }
say() { printf '\n==> %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" != 0 ] || { echo "run this as your normal user, not root (it asks for sudo when needed)"; exit 1; }

say "Checking the system"
if have plasmashell; then echo "plasma: $(plasmashell --version)"; else echo "plasmashell not found: this widget is for KDE Plasma 6"; exit 1; fi
case "$(plasmashell --version 2>/dev/null)" in *" 6."*) ;; *) echo "Plasma 6 is required"; exit 1 ;; esac

# ---- packages
if have pacman; then
    say "Installing the packages (Arch Linux)"
    run sudo pacman -S --needed base-devel git cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava
else
    missing=""
    for t in git cmake ninja g++ pkg-config python3; do have "$t" || missing="$missing $t"; done
    pkg-config --exists Qt6Core Qt6Qml Qt6WebSockets 2>/dev/null || missing="$missing qt6-base/declarative/websockets-development-files"
    pkg-config --exists icu-uc 2>/dev/null || missing="$missing icu-development-files"
    if [ -n "$missing" ]; then
        echo "Missing:$missing"
        echo "Install them with your package manager (Qt 6.4 or newer, CMake 3.21+, a C++20 compiler), then run this again."
        echo "Optional: cava (the visualizer) and plasma-browser-integration (YouTube titles)."
        [ "$DRY" = 1 ] || exit 1
    fi
fi

# ---- the source: this folder when run from a clone, else a copy kept under ~/.local/share/lyric-widget/source
here="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$here/CMakeLists.txt" ] && [ -d "$here/src" ]; then
    src="$here"
else
    src="${XDG_DATA_HOME:-$HOME/.local/share}/lyric-widget/source"
    say "Getting the source into $src"
    if [ -d "$src/.git" ]; then run git -C "$src" pull --ff-only
    else run git clone --depth 1 https://github.com/AWeebTaku/Lyrics-Widget "$src"; fi
fi

# ---- build and install the plugin and its data (not the widget files: the Store provides those)
say "Building"
run cmake -B "$src/build-plugin" -S "$src" -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DPLUGIN_ONLY=ON -DCMAKE_INSTALL_MESSAGE=NEVER --log-level=WARNING
run cmake --build "$src/build-plugin"
say "Installing (needs sudo)"
run sudo cmake --install "$src/build-plugin"

say "Japanese romanization (optional, private Python environment, about 30 seconds the first time)"
if [ "$DRY" = 1 ]; then echo "+ $src/setup-romaji.sh"; else "$src/setup-romaji.sh" || echo "(not set up; the widget uses a simpler converter)"; fi

say "Restarting Plasma so it finds the plugin"
run rm -rf "$HOME/.cache/plasmashell/qmlcache"
run systemctl --user restart plasma-plasmashell

cat <<'MSG'

Done. If you have not added the widget yet: right-click the desktop, Add or Manage Widgets, Get New Widgets,
search "Lyric Widget", install it, then drag it onto the desktop.
To check the system at any time: bash /usr/share/lyric-widget/doctor.sh
MSG
