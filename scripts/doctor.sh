#!/usr/bin/env bash
# Checks the things the Lyric Widget needs and prints a report you can paste into a bug report. It only reads: it
# changes nothing and sends nothing anywhere.
#   bash /usr/share/lyric-widget/doctor.sh
set -u
section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
ok() { printf '  ok       %s\n' "$1"; }
warn() { printf '  MISSING  %s\n' "$1"; }

section "System"
[ -r /etc/os-release ] && . /etc/os-release && echo "  distro:  ${PRETTY_NAME:-unknown}"
echo "  kernel:  $(uname -r)"
echo "  plasma:  $(plasmashell --version 2>/dev/null || echo 'not found')"
echo "  session: ${XDG_SESSION_TYPE:-unset} / ${XDG_CURRENT_DESKTOP:-unset}"

section "The widget"
plasmoid=""
for d in /usr/share/plasma/plasmoids/org.lyricwidget "$HOME/.local/share/plasma/plasmoids/org.lyricwidget"; do [ -d "$d" ] && plasmoid="$d" && break; done
if [ -n "$plasmoid" ]; then ok "installed at $plasmoid"; else warn "the plasmoid folder (run build.sh)"; fi
backend=""
for d in /usr/lib/qt6/qml/org/lyricwidget /usr/lib64/qt6/qml/org/lyricwidget; do [ -f "$d/liblyricbackend.so" ] && backend="$d" && break; done
if [ -n "$backend" ]; then ok "backend module at $backend"; else warn "the backend module org.lyricwidget (liblyricbackend.so)"; fi
if [ -n "$plasmoid" ]; then
  n=$(find "$plasmoid/contents" -name '*.qsb' | wc -l)
  if [ "$n" -ge 5 ]; then ok "$n compiled shaders (GPU visualizer styles and liquid glass)"; else warn "compiled shaders (found $n, expected 5 or more)"; fi
fi

section "The visualizer (cava)"
if have cava; then
  ok "cava: $(cava -v 2>&1 | head -1)"
else
  warn "cava (needed for the visualizer): sudo pacman -S cava | sudo apt install cava | sudo dnf install cava"
fi
if have pactl; then
  echo "  sound server: $(pactl info 2>/dev/null | sed -n 's/^Server Name: //p')"
  echo "  audio sources:"
  pactl list short sources 2>/dev/null | awk '{printf "    %s  %s  %s\n", $1, $2, $NF}' | head -8
else
  warn "pactl (to list audio inputs); PipeWire or PulseAudio is expected"
fi

section "Players (MPRIS)"
if have busctl; then
  list=$(busctl --user list --no-legend 2>/dev/null | awk '{print $1}' | grep '^org.mpris.MediaPlayer2\.' || true)
  if [ -n "$list" ]; then echo "$list" | sed 's/^/  /'; else echo "  none running (start a player to see lyrics)"; fi
else
  warn "busctl (to list players)"
fi

section "Lyrics"
db="$HOME/.local/share/plasmashell/lyrics.db"
if [ -f "$db" ]; then
  ok "database $db ($(du -h "$db" | cut -f1))"
  if have sqlite3; then
    echo "  cached songs:   $(sqlite3 -readonly "$db" 'select count(*) from lyrics_v6' 2>/dev/null)"
    echo "  library songs:  $(sqlite3 -readonly "$db" 'select count(*) from library' 2>/dev/null)"
  fi
else
  echo "  no database yet (it is made the first time a song plays)"
fi
echo "  romanization helper: $([ -x "$HOME/.local/share/lyric-widget/venv/bin/python" ] && echo ready || echo 'not set up (setup-romaji.sh), optional')"
echo "  custom QML folders:"
for d in visualizers progress buttons; do
  f="$HOME/.local/share/lyric-widget/$d"
  echo "    $d: $([ -d "$f" ] && ls "$f"/*.qml 2>/dev/null | wc -l || echo 0) file(s)"
done

section "Recent messages from the widget"
if have journalctl; then
  journalctl --user -b -u plasma-plasmashell 2>/dev/null | grep -iE "org.lyricwidget|lyricbackend" | grep -viE "graphics scene" | tail -8 | sed 's/^/  /'
else
  echo "  journalctl not found"
fi
echo
echo "Done. If something above says MISSING, that is the place to start."
