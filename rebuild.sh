#!/usr/bin/env bash
# Clean rebuild + reinstall + restart. Wipes: build dir, lyrics cache, plasmashell QML cache.
set -euo pipefail
cd "$(dirname "$0")"

./setup-romaji.sh || echo "(romanization helper not set up; the widget falls back to kakasi)"
rm -rf build
rm -f  "$HOME"/.local/share/plasmashell/lyrics.db{,-wal,-shm}   # lyrics cache (re-fetched on play)
rm -rf "$HOME"/.cache/plasmashell/qmlcache                      # stale compiled QML

cmake -B build -S . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
systemctl --user restart plasma-plasmashell
echo "done: widget rebuilt, caches cleared, plasmashell restarted"
