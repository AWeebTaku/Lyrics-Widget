# Lyric Widget for KDE Plasma 6

Synced lyrics on your desktop for **Spotify** and for **YouTube / YouTube Music in a browser**, with romanization,
text styles, an audio visualizer, a media card and look-ahead for shuffled queues. A native Plasma widget: QML for the
interface, a C++ plugin for everything else.

## Features

- **Timed lyrics** for the song playing, switching line by line from the player's position, with a smooth swipe and fade
  between lines scaled to the song's pace. Seeks are never missed.
- **Many sources, matched carefully.** Spotify songs are first asked of the Spotify app itself (exact, by track id).
  Otherwise LRCLIB, NetEase, QQ Music and Kugou are searched in parallel and scored on title, artist, length and album,
  with cross-script matching (`ヨルシカ` = `Yorushika`). No accounts or keys. Songs in several languages, sped-up or
  slowed uploads, TV-size cuts and extended mixes are recognized and matched to the right lyrics.
- **Lyrics from your own files:** a `.lrc` beside the song file, an optional folder of `.lrc` files, and lyrics stored in
  MP3 and FLAC tags, used before any online lookup. A `.romaji.lrc` beside it gives the pronunciation; a `.chapters` or
  `.cue` file puts chapter marks on the seek bar.
- **Romanization** of Japanese, Korean and Chinese lines, replacing the original line: the provider's, human-made
  furigana, or a local MeCab/UniDic converter.
- **Karaoke effect** (off by default): the words of the current line light up one by one as they are sung, from word-timed
  lyrics where a provider has them. The library's **Word timing** tab edits the times of any line.
- **Lyrics library:** fetch the lyrics of the playing song, edit them, stretch or thin out the timing and save them.
  Saved lyrics win over every provider. Searching understands edits: "Alright by Kendrick Lamar, but ..." finds the
  original and stretches it to the length of the song that is playing.
- **Audio visualizer:** bars, wave, blocks, peak bars, LED meter, mountain, oscilloscope, pixel matrix, floating dots, tech
  line, radial burst, pulse orb, ribbon, sparkles, gravity sparks, and GPU styles (plasma, terrain, tunnel). Smoothing,
  bass and treble weighting, color modes (palette, rainbow, cover colors), glow, 36 built-in looks you can save, share
  as text and randomize, and a battery saver.
- **Media card:** the cover (sharp, rounded, squircle, circle, vinyl record or CD), title and details, buttons, eleven seek-bar
  styles, ten layouts, seven backgrounds, a pill for Plasma panels. Every part of every layout can be hidden, moved,
  resized and faded.
- **Dynamic colors:** up to four colors from the album cover for the lyrics, the visualizer and the card accent.
- **Your own styles:** visualizers, seek bars and buttons written as QML files (opt-in, not sandboxed; see
  [docs/custom-styles.md](docs/custom-styles.md)).
- **Look-ahead:** lyrics of the next songs in the (shuffled) queue are fetched in advance (Spotify app, YouTube Music
  through a small browser extension).
- **Several copies:** each copy of the widget has its own settings and its own settings window; several can be open at once.

[docs/gallery.md](docs/gallery.md) shows the built-in looks.

## Requirements

| For | You need |
|---|---|
| Building | KDE Plasma 6 (with its development files), Qt 6.4 or newer (base, declarative, websockets), CMake 3.21+, Ninja, a C++20 compiler, ICU |
| Chrome or YouTube Music | the **Plasma Browser Integration** extension and the `plasma-browser-integration` host package |
| Accurate Japanese romanization (optional) | Python 3 |
| Audio visualizer (optional) | `cava` |
| Spotify lyrics and look-ahead (optional) | Spotify with [Spicetify](https://spicetify.app), started with a remote debugging port |

Packages (names differ between distributions). On Arch Linux:

```
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava
```

## Install

```
git clone https://github.com/AWeebTaku/Lyrics-Widget && cd Lyrics-Widget
./build.sh
```

`build.sh` sets up the romanization helper (first run only, about 30 seconds and 270 MB), builds, installs into `/usr` with
`sudo`, clears the cached lyrics table and plasmashell's QML cache, and restarts plasmashell. Your widget settings and your
per-song sync offsets are kept.

Then right-click the desktop, **Add or Manage Widgets**, drag **Lyric Widget** onto it, and play something.
Right-click the widget and choose **Configure…** for the settings.

Manual build:

```
cmake -B build -S . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
systemctl --user restart plasma-plasmashell
```

On Arch Linux you can also build a package: `cd packaging/arch && makepkg -si`.

Installed files: `/usr/lib/qt6/qml/org/lyricwidget/` (the C++ plugin), `/usr/share/plasma/plasmoids/org.lyricwidget/` (the
widget), `/usr/share/lyric-widget/` (the browser extension, the romanization script, the doctor script, examples).

To remove everything: `./uninstall.sh --dry-run` shows what it would do, `./uninstall.sh` asks first. It keeps the source
folder. Remove the browser extension yourself in the browser.

To check what is missing on a system: `bash /usr/share/lyric-widget/doctor.sh` (it only reads and prints).

## Setting up the sources

Each of these is optional. The widget works with just a player that reports what it plays (see "Players").

### The audio visualizer (cava)

The visualizer draws what **cava** hears. cava is a separate program that analyses the sound your computer plays.

1. Install `cava` with your package manager.
2. Turn the visualizer on: **Configure, General, Visualizer**.
3. That is all in the usual case. By default the widget captures the **monitor** of your default sound output, which is
   everything you hear.

A *monitor* is the sound server's copy of what an output device is playing. To capture something else, or if the visualizer
stays flat:

- List the sources: `pactl list sources short` (works with PipeWire and PulseAudio). Monitors end in `.monitor`.
- On PipeWire you can also use `wpctl status` to see the devices and their names.
- Open **Configure, Audio input**. Set **Method** to PipeWire or PulseAudio (or leave it on Default) and put the source's
  name in **Source**, or press **Choose from the list** and click one. Leave **Source** empty for "the default output".
- To react to a microphone or line-in instead, pick that device's source (not a monitor).
- Press **Apply**. The widget restarts cava by itself.

If nothing moves: check that `cava` is installed (`cava -v`), that sound is actually playing, and that the source is not muted.

### Spotify (lyrics from the Spotify app, and look-ahead)

Without this the widget reads Spotify like any other player and searches the online providers. With it, lyrics are asked
of the Spotify app itself (exact, by track id) and the shuffled queue is known in advance. The widget connects to a local
debugging port of the Spotify app and only reads (queue, lyrics); nothing in Spotify is changed.

1. Install **Spicetify** by following its own installation guide, then run `spicetify backup apply`.
2. Start Spotify with a remote debugging port, for example `spotify --remote-debugging-port=8088`. To make that permanent,
   copy Spotify's launcher to `~/.local/share/applications/` and add the flag to its `Exec=` line, or put the flag in
   Spicetify's launch flags (see its documentation for the exact setting name in your version).
3. Check that the port answers: `curl -s http://127.0.0.1:8088/json` should print a list that mentions Spotify.
4. **Configure, Sources**: turn on *Get lyrics and the queue from the Spotify app*, keep the port at 8088 (or enter yours),
   and press **Test the connection**.

A debugging port is powerful for any program running as you. Keep it only on `127.0.0.1` (the default for this flag) and
turn the setting off when you do not want it.

### YouTube and YouTube Music in a browser

1. Install the **Plasma Browser Integration** package (`plasma-browser-integration`) and its extension in your browser,
   and enable media controls in the extension's settings. Without it the browser shows `Song | YouTube Music` and no artist.
2. **Configure, Sources, Players**: the websites the widget follows are listed there; tick the ones you use.

To know the *Up next* list ahead of time (look-ahead for YouTube Music), install the small extension from this project.
It talks only to `127.0.0.1` and runs only on `music.youtube.com`:

1. **Configure, Sources**: turn on *Get the queue from YouTube Music* and Apply. Check with
   `curl -i http://127.0.0.1:8899/ping`.
2. On the same page choose your browser and press **Install the extension**, turn on **Developer mode**, **Load unpacked**,
   and pick the folder shown (use **Copy the path**; press `Ctrl+L` in the dialog).
3. Open music.youtube.com, reload the tab, play from a playlist and open **Up next** once. Then
   `curl -s http://127.0.0.1:8899/status` lists the queue.

If it stays empty, look at the extension's service worker console. YouTube changes its page now and then, so
`extension/page.js` may need a small update. If you change the port in the widget, change `PORT` in
`extension/background.js` too.

### Other players

By default the widget follows Spotify and the websites listed above. Turn on **Follow any media player** (Sources, Players)
to follow VLC, mpv, Strawberry, Elisa and any other player that reports what it plays through the standard media interface
(MPRIS). Lyrics are then found online by title and artist.

### Lyrics from your own files

For a song played from a file the widget looks, before any online lookup, for `Song.lrc` beside it (or `Song.ext.lrc`), for
`Artist - Title.lrc` or `Title.lrc` in the folder you set in **Sources**, and for lyrics stored inside the file (MP3 and FLAC).

### Japanese romanization

`./setup-romaji.sh` (run by `build.sh`) makes a private Python environment with MeCab and UniDic. Nothing is installed
system-wide and no root is needed. Without it the widget falls back to a simpler converter.

## Settings

Right-click the widget and choose **Configure…**. Seven pages, one per part of the widget. Each page is a list of groups
(open one to see its settings; **Reset** puts a group back to its defaults), has a search box, and shows only the options that
apply to what you chose. Each setting has a short line under it saying what it does.

- **General:** what to show (lyrics, visualizer, card), the widget's size on the desktop, when it hides or pauses, and power
  saving.
- **Lyrics:** what is shown, the text, the colors, the effects (shadow, outline, highlight bar), timing, the hover buttons and
  the position.
- **Visualizer:** looks first (built in and your own), then the style, colors, how it reacts to the music, and its position.
- **Audio input:** where the sound comes from, what is drawn, the level and pitch range, and the equalizer.
- **Card:** the layout, the background and glow, the cover, buttons, seek bar, title and details, and the pill for panels.
  **Edit the layout** lets you turn any part of a layout on or off, move it, resize it and fade it, for each layout on its
  own, with quick choices such as "Only this".
- **Sources:** lyric files, next songs, the Spotify app, YouTube Music, other players and websites.
- **Lyrics library:** get, edit, retime and save lyrics.

Plasma shows only one settings dialog at a time, so **Configure…** opens the settings in a window that belongs to that
widget. With several copies of the widget on the desktop, each has its own settings and its own window, and they can all be
open together. On KDE's window manager the windows open in the middle of the screen.

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

- **Matching.** Candidate titles are derived from the player's text (`Artist「Song」`, dash splits, variant tags). Each result
  is scored on title, artist, duration and album; weak results are rejected (instrumental, karaoke, placeholders, wrong
  artist). The best synced result wins, complete copies beat copies with a missing verse, and the first answer is shown
  and upgraded when better data arrives. A provider silent for a few seconds is left out.
- **Caching.** Settled answers are saved; failures and unsynced-only answers are not, and are retried quietly.
- **Look-ahead.** Up to five upcoming songs, one at a time, never while a window covers the widget.
- **Cover colors.** Taken from the picture the widget shows, falling back to the player's own cover, with patient retries.

## Privacy and security

- **Leaves your computer:** lyric searches to LRCLIB, NetEase, QQ Music and Kugou (title, artist, album, length), the video id
  to YouTube (for its own lyrics and the video's title), the song title to UtaTen for Japanese readings (furigana), and
  the album-art request to the player's own CDN. Optional online facts about a song (MusicBrainz, Wikipedia) are off by
  default. No account, identifier or telemetry. Kugou is queried over plain HTTP.
- **Local listeners, `127.0.0.1` only:** port `8899` for the browser extension (off unless enabled).
- **Files:** `~/.local/share/plasmashell/lyrics.db` (cache, offsets and your lyrics library) and
  `~/.local/share/lyric-widget/` (the romanization environment and your own styles).
- Lyrics belong to their owners and come from third-party services under their own terms.

## Troubleshooting

| Problem | Try |
|---|---|
| No lyrics for a song | `mkdir -p ~/.cache/lyric-widget && touch ~/.cache/lyric-widget/debug`, restart plasmashell, replay; then `journalctl --user -u plasma-plasmashell -n 300 \| grep -E "netease\|kugou\|publish"` shows each provider's pick |
| Browser shows `Song \| YouTube Music` with no artist | install and enable **Plasma Browser Integration** |
| Wrong Japanese readings | make sure `./setup-romaji.sh` finished; readings come from the furigana service when it has the song |
| Visualizer blank | see "The audio visualizer (cava)" above; `bash /usr/share/lyric-widget/doctor.sh` |
| Spotify route does not connect | see "Spotify" above; the port must answer `curl http://127.0.0.1:8088/json` |
| See errors | `journalctl --user -b \| grep -i -E "lyric\|org.lyricwidget"` |

## Known limits

- Some songs have no synced lyrics anywhere; unsynced text is shown as a static block.
- Provider interfaces are unofficial and can change or rate-limit without notice.

## Roadmap

Not done yet, in rough order of how likely they are:

- **Publishing:** submit the package to the AUR and the widget to the KDE Store.
- **A shared database of timed lyrics:** people contribute line-timed and word-timed lyrics for songs no provider has (covers,
  remixes, fan uploads). Open questions: the legal side of hosting lyric text, a song fingerprint that two people share, free
  hosting, and moderation. First small steps: export the lyrics library to a documented JSON format, and an optional upload
  of edited lyrics to LRCLIB.
- **Card and visualizer extras:** separate refraction and highlight sliders for the glass look, a full bloom pass, swipe
  gestures on the card, a position and margin for the buttons, a Plasma system-font option, and separately saved popup and
  pill presets.
- **Other places to run:** versions for other desktops, and translations.
- **Checks still to do:** the settings and card in a dark Plasma theme (the colors follow the theme, but it has not been
  looked at), and the YouTube Music queue extension against more page versions.

## Project layout

```
CMakeLists.txt  build.sh  uninstall.sh  setup-romaji.sh
src/        C++ plugin (QML module org.lyricwidget): player watching, lyric lookup and matching, cache, library,
            visualizer analysis, window placement
plasmoid/   the widget: metadata.json, contents/ui (the widget, the card, the visualizer, the settings),
            contents/config (main.xml: the settings schema), contents/kwin (the window-centering script)
romaji/     the MeCab + UniDic helper run in the private Python environment
extension/  browser extension (Manifest V3) for the YouTube Music queue
examples/   example visualizers, seek bars and buttons you can copy
tools/      doctor.sh (checks a system), gen-settings.js (writes the settings pages), gallery/ (renders the gallery)
tests/      table-driven checks of the lyric matching, the layouts and the settings
docs/       the gallery and the guide to writing your own styles
packaging/  arch/PKGBUILD for Arch Linux
```

The settings are defined once, in `plasmoid/contents/ui/settings/model.js`. `node tools/gen-settings.js` writes the page files
Plasma needs from it, and `tests/settings.test.js` checks the model against `config/main.xml` and those files.

## Tests

```
cmake -B build -S . -G Ninja -DBUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

They need no framework and no network. Node is needed for the settings, layout and preset checks.

## Lyric sources and terms

Lyrics are fetched while you listen and are not part of this repository; they belong to their rights holders. The cache and
your library keep copies on your own machine for your own use. LRCLIB is a community-run open database. NetEase Cloud Music,
QQ Music and Kugou are asked through their public web endpoints without accounts or keys: these are unofficial, can change
or stop at any time, and their terms may not allow automated use, so check them before relying on this. With the karaoke
effect on, the same three also give word-timed lyrics. Spotify's lyrics are read from the Spotify app on your own computer
with your own session. This project is not affiliated with any of these services. When a provider is slow or down the
widget waits a few seconds for it, retries throttled requests, and leaves a provider that fails repeatedly alone for a
minute, so the others answer without delay.

## License

GPL-3.0 (see `LICENSE` and `NOTICE`).
