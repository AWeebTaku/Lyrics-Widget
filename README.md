# Lyric Widget for KDE Plasma 6

Synced lyrics on your desktop for **Spotify** and for **YouTube / YouTube Music in a browser**. It also has an audio
visualizer, a media card, romanization of Japanese, Korean and Chinese, and colors taken from the album cover. It is a native
Plasma widget: QML for the interface, a C++ plugin for everything else.

Website: <https://aweebtaku.github.io/Lyrics-Widget/> (the source is `docs/index.html`). See also the [gallery of looks](docs/gallery.md).

## What you get

- **Timed lyrics** that follow the song line by line, with a smooth swipe and fade between lines. Seeking is never missed.
- **Many lyric sources, matched carefully.** Spotify songs are asked of the Spotify app first (exact, by track id). Otherwise
  LRCLIB, NetEase, QQ Music and Kugou are searched in parallel and scored on title, artist, length and album. No accounts or
  keys.
- **Your own lyrics.** A `.lrc` file beside the song, a folder of `.lrc` files, or lyrics stored in MP3 and FLAC tags are
  used before any online lookup.
- **Romanization** of Japanese, Korean and Chinese lines, replacing the original line.
- **Karaoke effect** (off by default): the words of the current line light up as they are sung.
- **Lyrics library:** fetch, edit, retime and save lyrics. Saved lyrics win over every provider.
- **Audio visualizer** with 23 styles (bars, wave, blocks, LED meter, mountain, oscilloscope, orb, ribbon, plasma, terrain,
  tunnel and more), colors, glow and a battery saver.
- **Media card** with 10 layouts, 6 cover shapes (sharp, rounded, squircle, circle, record, CD), 11 seek bar styles, several
  backgrounds and a pill for Plasma panels. Every part of every layout can be hidden, moved, resized and faded.
- **36 built-in looks** you can apply in one click, save, share as text and randomize.
- **Cover colors** for the lyrics, the visualizer and the card.
- **Your own styles:** visualizers, seek bars and buttons written as QML files (see [docs/custom-styles.md](docs/custom-styles.md)).
- **Look-ahead:** lyrics of the next songs in a shuffled queue are fetched in advance.
- **Several copies:** each copy of the widget has its own settings and its own settings window.

## Install

You need KDE Plasma 6 and the packages below. On Arch Linux:

```
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava
git clone https://github.com/AWeebTaku/Lyrics-Widget && cd Lyrics-Widget
./build.sh
```

`build.sh` (the whole widget from this folder) sets up the romanization helper (first run only, about 30 seconds and 270 MB), builds, installs into `/usr` with
`sudo`, clears the cached lyrics table and Plasma's QML cache, and restarts plasmashell. Your settings and per-song sync
offsets are kept. (If you downloaded a zip instead of cloning, run `bash build.sh`.)

Then right-click the desktop, choose **Add or Manage Widgets**, drag **Lyric Widget** onto it and play something.
Right-click the widget and choose **Configure…** for the settings.

**From a GitHub release (one file, does everything):** each release has `lyric-widget.sh`, which downloads, builds and installs
the whole widget, looks for updates and removes it again. No clone needed:

```
curl -fsSLO https://github.com/AWeebTaku/Lyrics-Widget/releases/latest/download/lyric-widget.sh
bash lyric-widget.sh              # install the latest release
bash lyric-widget.sh check        # is there a newer release?
bash lyric-widget.sh update       # install it
bash lyric-widget.sh uninstall    # remove the widget (add --purge to delete your lyrics library too)
```

`--dry-run` shows what any command would do, `-y` skips the questions, `--version v2.1.0` picks a release. It installs
packages itself on Arch Linux; on other systems it lists what is missing. It asks for your password only for the install
into `/usr`, and keeps its files in `~/.local/share/lyric-widget`.

| For | You need |
|---|---|
| Building | Plasma 6 development files, Qt 6.4 or newer (base, declarative, websockets), CMake 3.21+, Ninja, a C++20 compiler, ICU |
| YouTube or YouTube Music | the **Plasma Browser Integration** extension and the `plasma-browser-integration` package |
| Accurate Japanese romanization (optional) | Python 3 |
| Audio visualizer (optional) | `cava` |
| Spotify lyrics and look-ahead (optional) | Spotify with [Spicetify](https://spicetify.app), started with a remote debugging port |

Other ways to build:

```
cmake -B build -S . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr     # by hand
cmake --build build
sudo cmake --install build
systemctl --user restart plasma-plasmashell

cd packaging/arch && makepkg -si                              # an Arch package
```

**Where things go:** the C++ plugin in `/usr/lib/qt6/qml/org/lyricwidget/`, the widget in
`/usr/share/plasma/plasmoids/org.lyricwidget/`, and the browser extension, romanization script, doctor script and examples in
`/usr/share/lyric-widget/`.

**Check a system:** `bash /usr/share/lyric-widget/doctor.sh` only reads and prints what is missing.

**Remove everything:** `./uninstall.sh --dry-run` shows what it would do, `./uninstall.sh` asks first. It keeps the source
folder. Remove the browser extension yourself in the browser.

## Settings

Right-click the widget, **Configure…**. The settings open in a window that belongs to that widget (Plasma shows only one
settings dialog at a time), so several widgets can have their settings open together.

| Page | What it holds |
|---|---|
| General | what to show (lyrics, visualizer, card), size on the desktop, when it hides, power saving |
| Lyrics | what is shown, text, colors, effects (shadow, outline, highlight bar), timing, hover buttons, position |
| Visualizer | the looks, then style, colors, how it reacts to the music, position |
| Audio input | where the sound comes from, what is drawn, level and pitch range, equalizer |
| Card | layout, background, cover, buttons, seek bar, title and details, the pill for panels |
| Sources | your own lyric files, next songs, the Spotify app, YouTube Music, other players |
| Lyrics library | get, edit, retime and save lyrics |

How the pages work:

- **Live preview.** Lyrics, Visualizer and Card each show a live, animated preview at the top. Press **Listen to my music** on
  it to see your real music: the visualizer draws the sound playing now (needs `cava`), the card shows the real title, cover,
  colors and lyric line, and the lyrics preview shows the real lines.
- **Looks.** The Visualizer page shows the 36 looks as picture cards in groups (Favorites, Visualizer, Cards and layouts,
  Mine). Click one to apply it. **Random look**, **Look of the day** and **Save current look** are cards too. A look can set
  settings from other pages, and the General page follows.
- **Colors from the cover.** Pick it in **Visualizer, Colors, Color mode**, or turn on **Use colors from the album cover** on
  the Lyrics page.
- **Edit the layout** (Card page). Turn any part of a layout on or off, move it, resize it and fade it, for each layout on its
  own. Positions are X and Y in pixels on a snap grid. "Only this" shows one part and hides the rest.
- **Search and notices.** Each page has a search box. If the lyrics, visualizer or card is off, a notice at the top of its page
  turns it on, and that also sets the General switch.
- **Same layout everywhere.** Labels have no units; the unit is in the box (` px`, ` %`, ` s`). Positions are X and Y, sizes
  are Width and Height.

## Set up your sources

Each of these is optional. The widget works with just a player that reports what it plays.

### Audio visualizer (cava)

The visualizer draws what **cava** hears. cava is a separate program that analyses the sound your computer plays.

1. Install `cava`.
2. Turn the visualizer on in **General** (or press **Turn it on** on the Visualizer page).
3. That is usually all. By default it captures the **monitor** of your default sound output, which is everything you hear.

To capture something else, or if the visualizer stays flat:

- List sources with `pactl list sources short` (PipeWire and PulseAudio). Monitors end in `.monitor`.
- Open **Audio input**, set **Method**, and put the source's name in **Source** (or press **Choose from the list**). Empty
  means the default output. A microphone or line-in works the same way.
- Press **Apply**. The widget restarts cava itself.
- Still nothing: check `cava -v`, that sound is playing and that the source is not muted.

### Spotify app (exact lyrics and look-ahead)

Without this the widget reads Spotify like any other player and searches the online providers. With it, lyrics are asked of the
Spotify app (exact, by track id) and the shuffled queue is known in advance. The widget only reads; nothing in Spotify is
changed.

1. Install **Spicetify** from its own guide and run `spicetify backup apply`.
2. Start Spotify with a debugging port, for example `spotify --remote-debugging-port=8088`. To make it permanent, add the flag
   to a copy of Spotify's launcher in `~/.local/share/applications/`.
3. Check: `curl -s http://127.0.0.1:8088/json` should print a list that mentions Spotify.
4. **Sources, Spotify:** turn on **Use the Spotify app**, keep the port at 8088 and press **Test the connection**.

The port is powerful for any program running as you. Keep it on `127.0.0.1` (the default) and turn the setting off when you
do not want it.

### YouTube and YouTube Music

1. Install the **Plasma Browser Integration** package and its browser extension, and enable media controls in the extension's
   settings. Without it the browser shows `Song | YouTube Music` and no artist.
2. **Sources, Players** lists the websites the widget follows. Tick the ones you use.

For look-ahead on YouTube Music, install the small extension from this project (it talks only to `127.0.0.1` and runs only on
`music.youtube.com`):

1. **Sources, YouTube Music and browsers:** turn on **Get the queue from YouTube Music** and press **Apply**.
2. Choose your browser, press **Install the extension**, turn on **Developer mode**, **Load unpacked** and pick the folder shown
   (**Copy the path**; press `Ctrl+L` in the dialog).
3. Open music.youtube.com, reload the tab, play from a playlist and open **Up next** once.
4. Press **Test the connection** to see whether the extension has sent a queue.

If it stays empty, look at the extension's service worker console. YouTube changes its page now and then, so
`extension/page.js` may need a small update. If you change the port in the widget, change `PORT` in `extension/background.js`
too. From a terminal: `curl -i http://127.0.0.1:8899/ping` and `curl -s http://127.0.0.1:8899/status`.

**Sources, Next songs, Check the next songs** shows what both the Spotify app and the extension can see, with one line each
saying what works and what to fix.

### Other players

Turn on **Follow any media player** (Sources, Players) to follow VLC, mpv, Strawberry, Elisa and any player that reports what it
plays through the standard media interface (MPRIS). Lyrics are then found online by title and artist.

### Your own files

For a song played from a file on your computer, the widget looks before any online lookup for `Song.lrc` beside it, for
`Artist - Title.lrc` or `Title.lrc` in the folder you set in **Sources**, and for lyrics stored inside the file (MP3 and FLAC).
This does nothing for Spotify and YouTube Music, which have no local file. A `.romaji.lrc` beside the song gives the
pronunciation, and a `.chapters` or `.cue` file puts chapter marks on the seek bar.

### Japanese romanization

`./setup-romaji.sh` (run by `build.sh`) makes a private Python environment with MeCab and UniDic. Nothing is installed
system-wide and no root is needed. Without it the widget falls back to a simpler converter.

## Troubleshooting

| Problem | Try |
|---|---|
| No lyrics for a song | `mkdir -p ~/.cache/lyric-widget && touch ~/.cache/lyric-widget/debug`, restart plasmashell, replay; then `journalctl --user -u plasma-plasmashell -n 300 \| grep -E "netease\|kugou\|publish"` shows each provider's pick |
| Browser shows `Song \| YouTube Music` with no artist | install and enable **Plasma Browser Integration** |
| Wrong Japanese readings | make sure `./setup-romaji.sh` finished; readings come from the furigana service when it has the song |
| Visualizer is blank | see "Audio visualizer" above, then `bash /usr/share/lyric-widget/doctor.sh` |
| Spotify route does not connect | see "Spotify app" above; the port must answer `curl http://127.0.0.1:8088/json` |
| A setting turns itself off after Apply | rebuild: older builds let the General page write its old value back |
| See errors | `journalctl --user -b \| grep -i -E "lyric\|org.lyricwidget"` |

Known limits: some songs have no synced lyrics anywhere (unsynced text is shown as a static block), and the provider
interfaces are unofficial and can change or rate-limit without notice.

## Privacy

- **Leaves your computer:** lyric searches to LRCLIB, NetEase, QQ Music and Kugou (title, artist, album, length), the video id
  to YouTube (for its own lyrics and the video's title), the song title to UtaTen for Japanese readings, and the album-art
  request to the player's own CDN. Optional online facts about a song (MusicBrainz, Wikipedia) are off by default. No account,
  identifier or telemetry. Kugou is queried over plain HTTP.
- **Local listener, `127.0.0.1` only:** port `8899` for the browser extension (off unless enabled).
- **Files:** `~/.local/share/plasmashell/lyrics.db` (cache, offsets and your lyrics library) and
  `~/.local/share/lyric-widget/` (the romanization environment and your own styles).

## How it works

```
 MPRIS players (Spotify, browsers, any player)
        |  D-Bus, event driven
        v
 PlayerWatcher --> LyricsController <--> LyricsStore (SQLite cache, per-song offsets, learned sources)
                     |   |   |
   Spotify app ------+   |   +---- timer per line, layered lines, word timing
   (exact lyrics)        |
                         +---- LyricsFetcher: LRCLIB | NetEase | QQ | Kugou  (parallel, scored, merged)
                         +---- ReadingFetcher: furigana -> romaji helper (MeCab + UniDic)
 QML: LyricStage (transition), AudioViz (cava + canvas), card, settings pages
```

- **Matching.** Candidate titles come from the player's text (`Artist「Song」`, dash splits, variant tags). Each result is
  scored on title, artist, duration and album; weak results (instrumental, karaoke, placeholders, wrong artist) are rejected.
  The best synced result wins, and the first answer is shown and upgraded when better data arrives. A provider silent for a few
  seconds is left out for a minute, so the others answer without delay.
- **Caching.** Settled answers are saved; failures and unsynced-only answers are not, and are retried quietly.
- **Look-ahead.** Up to five upcoming songs, one at a time, never while a window covers the widget.
- **Cover colors.** Taken from the picture the widget shows, falling back to the player's own cover.

## For developers

```
CMakeLists.txt  build.sh  uninstall.sh  setup-romaji.sh
.github/    issue and pull request templates, workflows/release.yml (publishes a release from a version tag)
CONTRIBUTING.md  SECURITY.md  CODE_OF_CONDUCT.md
src/        C++ plugin (QML module org.lyricwidget): player watching, lyric lookup and matching, cache, library,
            visualizer analysis, window placement
plasmoid/   the widget: metadata.json, contents/ui (widget, card, visualizer, settings), contents/config (main.xml: the
            settings schema), contents/kwin (the window-centering script)
romaji/     the MeCab + UniDic helper run in the private Python environment
extension/  browser extension (Manifest V3) for the YouTube Music queue
examples/   example visualizers, seek bars and buttons you can copy
tools/      doctor.sh (checks a system), gen-settings.js (writes the settings pages), gallery/ (renders the gallery)
tests/      table-driven checks of lyric matching, layouts, presets and settings
docs/       the website (index.html), the gallery, and the guide to writing your own styles
packaging/  arch/PKGBUILD for Arch Linux; release/lyric-widget.sh, the one-file installer, updater and uninstaller attached to
            each release, and notes.py, which writes the release notes
```

- **Settings are defined once**, in `plasmoid/contents/ui/settings/model.js`. After changing it, run
  `node tools/gen-settings.js` to write the page files Plasma needs. `tests/settings.test.js` checks the model against
  `config/main.xml`, the generated files and the label conventions (no unit in a label, a pair names its two boxes).
- **Run the tests** (no framework, no network; Node is needed for the settings, layout and preset checks):

  ```
  cmake -B build -S . -G Ninja -DBUILD_TESTS=ON
  cmake --build build
  ctest --test-dir build --output-on-failure
  ```

- **Make a release:** raise `Version` in `plasmoid/metadata.json`, add a `## <version>` section to `CHANGELOG.md`, commit, then
  `git tag v2.3.0 && git push origin v2.3.0`. The workflow in `.github/workflows/release.yml` publishes the release with
  `lyric-widget.sh` and `SHA256SUMS`. The notes are `.github/release-notes.md` plus that CHANGELOG section,
  so every release reads the same (`python3 packaging/release/notes.py v2.3.0` previews them).
- **Redraw the gallery** after changing a look: `tools/gallery/render.sh` (needs a display and a built backend). It writes
  `docs/gallery/*.png` and `docs/gallery.md`, and copies the pictures into the app for the settings window.

## Help, ideas and contributing

- **A problem?** Open an issue with the form; it asks for the facts that matter (`bash /usr/share/lyric-widget/doctor.sh` prints
  most of them). A security problem goes through the private "Report a vulnerability" form, see [SECURITY.md](SECURITY.md).
- **Want to add something?** [CONTRIBUTING.md](CONTRIBUTING.md) says where a setting, a look or a lyric rule lives and what to
  run before a pull request. Please follow the [code of conduct](CODE_OF_CONDUCT.md).

## Roadmap

Not done yet, in rough order of how likely they are:

- **Publishing:** the package on the AUR.
- **A shared database of timed lyrics** for songs no provider has (covers, remixes, fan uploads). Open questions: the legal side
  of hosting lyric text, a song fingerprint two people share, free hosting, and moderation. First steps: export the lyrics
  library to a documented JSON format, and an optional upload of edited lyrics to LRCLIB.
- **Card and visualizer extras:** refraction and highlight sliders for the glass look, a full bloom pass, swipe gestures on the
  card, position and margin for the buttons, a Plasma system-font option, separately saved popup and pill presets.
- **Other places to run:** other desktops, and translations.
- **Checks to do:** the settings and card in a dark Plasma theme, and the YouTube Music extension against more page versions.

## Lyric sources and terms

Lyrics are fetched while you listen and are not part of this repository; they belong to their rights holders. The cache and your
library keep copies on your own machine for your own use. LRCLIB is a community-run open database. NetEase Cloud Music, QQ Music
and Kugou are asked through their public web endpoints without accounts or keys: these are unofficial, can change or stop at any
time, and their terms may not allow automated use, so check them before relying on this. With the karaoke effect on, the same
three also give word-timed lyrics. Spotify's lyrics are read from the Spotify app on your own computer with your own session.
This project is not affiliated with any of these services.

## License

GPL-3.0 (see `LICENSE` and `NOTICE`).
