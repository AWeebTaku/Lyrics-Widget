#!/usr/bin/env bash
# Sets up accurate Japanese romanization (MeCab + UniDic via cutlet) in a private Python environment.
# Safe to run again; does nothing when it is already set up. No system packages, no root.
set -euo pipefail
VENV="$HOME/.local/share/lyric-widget/venv"
if "$VENV/bin/python" -c "import cutlet, fugashi, unidic_lite" 2>/dev/null; then
    echo "romanization: already set up"
    exit 0
fi
echo "romanization: setting up (one time, about 30 seconds, 270 MB of disk)..."
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet fugashi unidic-lite cutlet
"$VENV/bin/python" -c "import cutlet; print(cutlet.Cutlet().romaji('今日は天気がいい'))"
echo "romanization: ready"
