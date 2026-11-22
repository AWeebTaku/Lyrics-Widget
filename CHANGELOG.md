# Changelog

Each release's section is used for its GitHub release notes (`.github/workflows/release.yml`), so keep the heading as `## <version>`.

## 3.0.0

A big update to how looks work, a faster and clearer settings window, and fixes for the lyrics library and for skipping songs in Chrome.

- **A look no longer takes over everything.** It turns the visualizer on (and the card, for a card look) and sets the visualizer and card settings it is about. It leaves your lyrics, reduced motion, battery saver and dark-text choice alone, and the 16 visualizer looks no longer turn the card or the lyrics off. A look now also resets the visualizer's position and colors, the card's color sources and the layout edits, so it is a full snapshot (and so is **Save current look**).
- **Go back:** picking a look saves the setup it replaces as "Before the last look". A **Go back** button on the Looks page (and an entry in the widget's right-click menu, next to **Random look**) returns to it.
- Saving, favoriting and deleting looks no longer waits for Apply.
- **Lyrics library edits the song the widget is showing.** The library window used a player finder of its own, so with more than one player or tab (or with your player settings) it could pick another song than the widget did, save the lyrics under that song, and the widget never loaded them. It now follows the widget's own song, key and playing position (the settings dialog's copy uses the widget's "any player" and website settings).
- **Opening a settings page no longer freezes the window.** The first visit to a page took up to 1.8 s (Card), 0.9 s (Visualizer) and 0.6 s (Lyrics, Audio input) with the window stuck; it is now built a piece at a time (the longest stall measured is under 0.3 s, with "Opening the page…" in the footer), and the live preview redraws once when a page has filled itself instead of once per setting. Going back to a page was already instant.
- **Next and Previous greyed out** in Plasma's Media Player (and the media keys doing nothing) with YouTube Music in Chrome: the browser extension (now 0.3.0: reload it in `chrome://extensions` and reload the tab) registers the page's Next and Previous actions again every few seconds, which is what Chrome needs to report that it can skip. When Chrome still does not answer, the widget says so over the lyrics instead of doing nothing.
- **The hover button "Look for other lyrics"** (the reload icon): it no longer shows the same lyrics again under another id (copies identical to what is on screen are skipped), and every answer is shown over the widget for a few seconds ("Looking for other lyrics…", "Other lyrics from lrclib (kept for this song)", "No other lyrics found. Press again to start over.", "You saved these lyrics yourself. Remove them in the library to look for others."). Before, the answers were hidden behind the lyrics, so the button seemed to do nothing for a song you had saved.
- **Remove** in the library also forgets the cached result, so the widget really looks the song up again instead of showing the same wrong lyrics from the cache.
- Music videos named "Song - Artist" with a credit on the right ("平行線 - Eve × suis from ヨルシカ MV") are searched as that artist's song first, and a video named in two scripts ("平行線 - Heikousen") is searched with the player's artist under each name. A romaji title now also matches the database's original-script title when the artist and the length agree (YouTube Music shows "Heikousen", the databases have "平行線"). Piano and music-box versions are skipped.
- Music videos: titles that end in "Music Video", "Official MV", "Official Music Video 4K", "-Music Clip-", "- Topic" or repeat the artist ("... / Ado") are cleaned before lyrics are searched, and "Song | Other name" is tried under each name.
- **A tidier repository.** The scripts are in `scripts/` (`build.sh`, `uninstall.sh`, `setup-romaji.sh`, `doctor.sh`), so the top folder holds only the project files; the README, the website and the contributor notes describe the new layout. Run `./scripts/build.sh` from a clone (the release installer, `lyric-widget.sh`, is unchanged and still works for older releases).
- "Visualizer: off" now means off: Hero wave, Orbit and Poster no longer draw it on their own. A note on the Card page says those layouts need it.
- "Look up the song online" only works while the song details are on (it kept sending song names after its switch was hidden).
- "Blur the desktop behind" only applies to the glass backgrounds it is shown for.
- Removed settings that did nothing: Glass tint and the "Size in a panel" group (Fill the panel's length, Fixed length, Minimum length, Fill the panel's thickness).
- Audio input: Channels is one or two, and Auto connect is Never, Only at the start or Keep reconnecting (the old ranges were wrong for cava).
- The Reset button of the Card, Layout group no longer clears the edits of every layout. Cover and title size are set in one place each.
- The settings previews use all your settings (the card preview ignored your lyric font and colors, and the Looks preview showed only the visualizer). The Looks preview shows what the widget shows now.
- **Settings window:** the preview sits centered on its own stage, the first group of a page is open, **Open all** and **Close all**, a clearer notice when a part is off, Apply waits for changes and the footer counts them ("3 changes not applied yet", Close becomes Discard and close), Looks has filters and no list inside the page, and the Looks page has a brush icon.
- "Nothing is playing yet: start a song in Spotify or your browser." instead of "Waiting for Spotify or Chrome…".

## 2.4.0

- The **Layout** page is gone. On the Card page every part has its on/off switch, place and size next to its other settings (Background, Cover, Buttons, Seek bar, Title and details, Lyrics and visualizer, Corner buttons). The changes belong to the layout in use, and **Reset this layout** puts them back.
- The cover can be turned on and placed in any layout, including the ones that have none (Hero wave, Poster, Compact).
- A color for the song title (the buttons and the seek bar already had one).
- Next and Previous on YouTube Music: when Chrome's media controls stop answering, the browser extension (version 0.2.0, reload it after updating) presses the page's own button, so Chrome no longer needs a restart.

## 2.3.0

- The looks have their own **Looks** page, between Card and Sources. The Visualizer page now starts at Style.
- "Edit the layout" moved from the Card page to its own **Layout** page, after Looks. The Looks and Layout pages have no folding heading.
- Fixed the pictures of the Slim strip, Mirrored minimal and Compact looks, and tall pictures that ran out of the landing page viewer.
- Fixed settings that a look could no longer change once you had edited them by hand: a look now updates every control, and you can edit it afterwards.
- Removed the KDE Store packaging: the Store package, the plugin-only installer, the setup screen shown when the plugin is missing, and the `--plugin-only` and `--source` options of `lyric-widget.sh`. The widget is distributed from GitHub (the release installer, `build.sh`, or the Arch package).

## 2.2.0

- The KDE Store package carries the plugin's source and the installer. When the plugin is missing, the widget shows a setup screen with an **Install the plugin** button instead of an error: it builds the plugin from the package, asks for your password once and restarts Plasma.
- The release installer `lyric-widget.sh` has `--plugin-only` (for a widget installed from the Store) and `--source DIR` (build from a folder you already have).
- `install.sh` in the repository installs the plugin and its data without the widget files.
- New community files: issue forms, a pull request template, `CONTRIBUTING.md`, `SECURITY.md` and `CODE_OF_CONDUCT.md`.
- The website's Install section has tabs for the release script, building from source and the Arch package.

## 2.1.0

- 36 built-in looks as picture cards, with Random look, Look of the day and Save current look.
- Live previews with a "Listen to my music" pill on the Lyrics, Visualizer and Card pages.
- Visualizer colors from the album cover, a next-songs check and a browser-extension connection test.
- A layout editor with X, Y, Width and Height in pixels on a snap grid.
- The "Turn it on" notices and looks now also change the General page, so Apply no longer turns them off again.
- A one-file installer, updater and uninstaller attached to each release, and a KDE Store package.
