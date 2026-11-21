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

After adding the widget it shows a setup screen with an "Install the plugin" button: it opens a terminal that builds the widget's
small C++ plugin from the source inside this package (nothing is downloaded), asks for your password once and restarts Plasma. It
needs Plasma 6, Qt 6, cmake and a C++ compiler; on Arch Linux the script installs them for you, on other distributions it lists what
is missing. Arch Linux is the tested system.

Source, README and help: https://github.com/AWeebTaku/Lyrics-Widget
