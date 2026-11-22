#!/usr/bin/env bash
# Lyric Widget: installer, updater and uninstaller in one file. It is attached to every GitHub release.
#
#   bash lyric-widget.sh               install the latest release (download, build, install)
#   bash lyric-widget.sh install       the same
#   bash lyric-widget.sh check         say whether a newer release exists
#   bash lyric-widget.sh update        install the latest release if it is newer than the one you have
#   bash lyric-widget.sh uninstall     remove the widget (asks first)
#   bash lyric-widget.sh version       the installed and the latest version
#
# Options:  --dry-run  only print what it would do      -y  no questions      --version TAG  a release other than the latest
#           --purge    uninstall: also delete the lyrics library, cached lyrics and your own styles
#
# It installs into /usr with sudo (asking for your password at that step), and keeps its own files in
# ~/.local/share/lyric-widget. Packages are installed for you on Arch Linux (the tested system); on other systems it checks the
# tools and lists what is missing.
set -euo pipefail

REPO="AWeebTaku/Lyrics-Widget"
HOME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lyric-widget"
STAMP="$HOME_DIR/installed-version"

DRY=0; YES=0; PURGE=0; WANT=""; CMD=""
while [ $# -gt 0 ]; do
    case "$1" in
        install | update | check | uninstall | version) CMD="$1" ;;
        --dry-run) DRY=1 ;;
        -y | --yes) YES=1 ;;
        --purge) PURGE=1 ;;
        --version) shift; WANT="${1:-}"; [ -n "$WANT" ] || { echo "--version needs a release tag, for example v2.1.0"; exit 2; } ;;
        -h | --help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1 (try --help)"; exit 2 ;;
    esac
    shift
done
CMD="${CMD:-install}"

run() { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }
say() { printf '\n==> %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "error: $*" >&2; exit 1; }
ask() {   # ask "question": yes when -y, no on an empty answer or without a terminal
    [ "$YES" = 1 ] && return 0
    local a=""
    if [ -t 0 ]; then read -r -p "$1 [y/N] " a; elif [ -r /dev/tty ]; then read -r -p "$1 [y/N] " a < /dev/tty; fi
    case "$a" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}
# 1 when $1 is a newer version than $2 (v prefixes ignored)
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "${1#v}" "${2#v}" | sort -V | tail -1)" = "${1#v}" ]; }
fetch() { if have curl; then curl -fsSL "$@"; elif have wget; then wget -qO- "${@: -1}"; else die "curl or wget is needed"; fi; }

installed_version() { [ -r "$STAMP" ] && cat "$STAMP" || echo ""; }
latest_tag() {
    local t
    t="$(fetch "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)" || true
    [ -n "$t" ] || die "could not read the latest release of $REPO (no network, or no release published yet)"
    echo "$t"
}

check_system() {
    have plasmashell || die "plasmashell not found: this widget is for KDE Plasma 6"
    case "$(plasmashell --version 2>/dev/null)" in *" 6."*) ;; *) die "Plasma 6 is required (found: $(plasmashell --version))" ;; esac
    [ "$(id -u)" != 0 ] || die "run this as your normal user, not root (it asks for sudo when needed)"
    have tar || die "tar is needed"
}

install_packages() {
    if have pacman; then
        say "Installing the packages (Arch Linux)"
        run sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava
    else
        local missing=""
        for t in cmake ninja g++ pkg-config python3; do have "$t" || missing="$missing $t"; done
        pkg-config --exists Qt6Core Qt6Qml Qt6WebSockets 2>/dev/null || missing="$missing qt6-base/declarative/websockets-development-files"
        pkg-config --exists icu-uc 2>/dev/null || missing="$missing icu-development-files"
        if [ -n "$missing" ]; then
            echo "Missing:$missing"
            echo "Install them with your package manager (Qt 6.4 or newer, CMake 3.21+, a C++20 compiler), then run this again."
            echo "Optional: cava (the visualizer) and plasma-browser-integration (YouTube titles)."
            [ "$DRY" = 1 ] || exit 1
        fi
    fi
}

do_install() {
    check_system
    local tag="${WANT:-}"
    [ -n "$tag" ] || tag="$(latest_tag)"
    local have_v; have_v="$(installed_version)"
    if [ -n "$have_v" ] && [ "$have_v" = "$tag" ] && [ "$CMD" = install ] && [ "$YES" != 1 ]; then
        ask "$tag is already installed. Build and install it again?" || { echo "nothing to do"; return 0; }
    fi
    say "Lyric Widget $tag"
    install_packages

    local src="$HOME_DIR/source/${tag#v}"
    say "Downloading $tag"
    run rm -rf "$src"
    run mkdir -p "$src"
    if [ "$DRY" = 1 ]; then echo "+ download https://github.com/$REPO/archive/refs/tags/$tag.tar.gz | tar -xz -C $src --strip-components=1"
    else fetch "https://github.com/$REPO/archive/refs/tags/$tag.tar.gz" | tar -xz -C "$src" --strip-components=1; fi
    [ "$DRY" = 1 ] || [ -f "$src/CMakeLists.txt" ] || die "no CMakeLists.txt in the source for $tag (is $tag a release of $REPO?)"

    say "Building"
    run cmake -B "$src/build" -S "$src" -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_MESSAGE=NEVER --log-level=WARNING
    run cmake --build "$src/build"

    say "Installing (needs sudo)"
    run sudo rm -rf /usr/share/plasma/plasmoids/org.lyricwidget      # so files removed in a newer version do not linger
    run sudo cmake --install "$src/build"

    say "Japanese romanization (optional, private Python environment, about 30 seconds the first time)"
    # the script moved to scripts/ in 3.0.0: an older release keeps it at the top
    romaji="$src/scripts/setup-romaji.sh"; [ -f "$romaji" ] || romaji="$src/setup-romaji.sh"
    if [ "$DRY" = 1 ]; then echo "+ $romaji"; else "$romaji" || echo "(not set up; the widget uses a simpler converter)"; fi

    say "Restarting Plasma"
    run rm -rf "$HOME/.cache/plasmashell/qmlcache"
    run systemctl --user restart plasma-plasmashell
    if [ "$DRY" != 1 ]; then mkdir -p "$HOME_DIR"; echo "$tag" > "$STAMP"; fi
    # keep only this source folder
    if [ "$DRY" != 1 ]; then for d in "$HOME_DIR"/source/*/; do [ "${d%/}" = "$src" ] || rm -rf "$d"; done; fi

    cat <<MSG

Done: Lyric Widget $tag is installed.
Right-click the desktop, Add or Manage Widgets, drag "Lyric Widget" onto it and play something.
Check the system:  bash /usr/share/lyric-widget/doctor.sh
Look for updates:  bash $(basename "$0") check
MSG
}

do_check() {
    local have_v latest; have_v="$(installed_version)"; latest="$(latest_tag)"
    echo "installed: ${have_v:-none (not installed by this script)}"
    echo "latest:    $latest"
    if [ -z "$have_v" ]; then echo "Run: bash $(basename "$0") install"; return 0; fi
    if newer "$latest" "$have_v"; then echo "A newer version is available. Run: bash $(basename "$0") update"; return 10
    else echo "You are up to date."; fi
}

do_update() {
    local have_v latest; have_v="$(installed_version)"; latest="${WANT:-$(latest_tag)}"
    if [ -n "$have_v" ] && ! newer "$latest" "$have_v" && [ -z "$WANT" ]; then echo "Already up to date ($have_v)."; return 0; fi
    echo "Updating ${have_v:-the widget} to $latest"
    CMD=update do_install
}

do_uninstall() {
    say "Uninstall Lyric Widget"
    echo "This removes the widget from your desktop and panels, the files in /usr (asks for sudo), and the romanization environment."
    if [ "$PURGE" = 1 ]; then echo "--purge: it also deletes your lyrics library, cached lyrics, per-song sync offsets and your own styles."
    else echo "It keeps your lyrics library, per-song sync offsets and your own styles (add --purge to delete them too)."; fi
    ask "Continue?" || { echo "cancelled"; return 0; }

    say "Removing the widget from the desktop"
    if have qdbus6 && qdbus6 org.kde.plasmashell >/dev/null 2>&1; then
        run qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var n = 0;
desktops().concat(panels()).forEach(function (c) { c.widgets().forEach(function (w) { if (w.type == "org.lyricwidget") { w.remove(); n++; } }); });
print("removed " + n + " widget(s)");'
    else echo "plasmashell is not reachable: remove the widget by hand (right-click it, Remove)."; fi

    say "Removing the installed files (needs sudo)"
    run sudo rm -rf -- /usr/lib/qt6/qml/org/lyricwidget /usr/lib64/qt6/qml/org/lyricwidget /usr/share/plasma/plasmoids/org.lyricwidget \
        /usr/share/lyric-widget /usr/share/icons/hicolor/scalable/apps/org.lyricwidget.svg
    run rm -rf -- "$HOME/.local/share/plasma/plasmoids/org.lyricwidget" "$HOME/.cache/lyric-widget" "$HOME/.cache/plasmashell/qmlcache"
    run rm -rf -- "$HOME_DIR/source" "$HOME_DIR/venv" "$STAMP"
    if [ "$PURGE" = 1 ]; then
        say "Deleting your data"
        run rm -f -- "$HOME/.local/share/plasmashell/lyrics.db" "$HOME/.local/share/plasmashell/lyrics.db-wal" \
            "$HOME/.local/share/plasmashell/lyrics.db-shm" "$HOME/.local/share/plasmashell/spotify.json"
        run rm -rf -- "$HOME_DIR"
    fi
    say "Restarting Plasma"
    run systemctl --user restart plasma-plasmashell
    echo
    echo "Removed. Remove the browser extension yourself if you installed it (chrome://extensions, 'Lyric Widget queue bridge')."
}

case "$CMD" in
    install) do_install ;;
    update) check_system; do_update ;;
    check) do_check ;;
    uninstall) do_uninstall ;;
    version) echo "installed: $(installed_version || true)"; echo "latest:    $(latest_tag 2>/dev/null || echo unknown)" ;;
esac
