# KDE Store listing (copy into the product page)

**Name:** Lyric Widget

**Category:** Plasma 6 widgets (Multimedia)

**License:** GPL-3.0

**Icon:** `icon.png` (512 x 512). **Package:** run `packaging/store/make-plasmoid.sh`, upload `build/org.lyricwidget-<version>.plasmoid`.

**Screenshots:** `docs/gallery/` renders (for example 02, 12, 20, 23), the settings window, the website.

**Summary:** Synced lyrics, an audio visualizer and a media card for Spotify and YouTube Music.

**Description:**

Synced lyrics on your desktop for Spotify and for YouTube / YouTube Music in a browser, with an audio visualizer, a media card
with 36 ready-made looks, romanization of Japanese, Korean and Chinese, karaoke word timing, your own lyric files and colors
from the album cover. No accounts or keys.

IMPORTANT: this widget needs its C++ plugin, which the Store cannot install. Before adding the widget, run:

    git clone https://github.com/AWeebTaku/Lyrics-Widget && cd Lyrics-Widget && ./install.sh

(Arch Linux is tested; on other distributions the script lists the packages you need.) Without the plugin Plasma shows
"module org.lyricwidget is not installed".

Source, README and help: https://github.com/AWeebTaku/Lyrics-Widget
