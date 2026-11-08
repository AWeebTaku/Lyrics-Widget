#!/usr/bin/env bash
# Clean build + install + restart. Wipes: build dir, cached lyrics, plasmashell QML cache.
# Keeps: your per-song sync offsets (and what the widget learned from them) in lyrics.db.
set -euo pipefail
cd "$(dirname "$0")"

./setup-romaji.sh || echo "(romanization helper not set up; the widget falls back to kakasi)"
rm -rf build
# cached lyrics only (re-fetched on play); the offsets / nudges / wins tables stay
python3 - "$HOME/.local/share/plasmashell/lyrics.db" <<'PY'
import os, sqlite3, sys
db = sys.argv[1]
if os.path.exists(db):
    con = sqlite3.connect(db)
    for (name,) in con.execute("select name from sqlite_master where type='table' and name like 'lyrics\\_%' escape '\\'").fetchall():
        con.execute(f'drop table "{name}"')
    con.commit()
    con.execute("vacuum")
    con.close()
PY
rm -rf "$HOME"/.cache/plasmashell/qmlcache                      # stale compiled QML

cmake -B build -S . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo rm -rf /usr/share/plasma/plasmoids/org.lyricwidget   # so files removed from the source do not linger
sudo cmake --install build
systemctl --user restart plasma-plasmashell
echo "done: widget rebuilt, caches cleared, plasmashell restarted"
