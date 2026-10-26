# Lyric Widget for KDE Plasma 6

Synced lyrics on your desktop for **Spotify** and **YouTube / YouTube Music in Chrome**, with
romanization, karaoke highlighting, an embedded audio visualizer and look-ahead for shuffled queues.
A native Plasma widget: QML for the interface, a C++ plugin for everything else.

> Status: personal project, developed and tested on Arch Linux with Plasma 6 and Qt 6.12. The repository has no
> test suite; features were checked against real songs and with throw-away test programs. Issues and patches welcome.

## Features

- **Timed lyrics** for the song playing, switching line by line from the player's position (one precise
  timer per line; while synced lyrics play the real position is checked twice a second, so seeks are never missed), with a
  smooth swipe-and-fade between lines scaled to the song's pace.
- **Many sources, matched carefully.** Spotify songs are first asked of the Spotify app itself (exact, by
  track id). Otherwise LRCLIB, NetEase, QQ Music and Kugou are searched in parallel and scored on title,
  artist, length and album, with cross-script matching (`ヨルシカ` = `Yorushika`). No accounts or keys.
- **Romanization replaces the original line** (Japanese, Korean, Chinese) when available: provider
  romanization, human-made furigana from UtaTen, or a local MeCab/UniDic converter.
- **Lyrics library:** a settings page to fetch the lyrics of the playing song, edit them, stretch or thin out the timing
  (percent, shift, or "first line at / last line at") and save them. Saved lyrics win over every provider and
  survive rebuilds. Searching from the page understands edits: "Alright by Kendrick Lamar, but ..." finds the original
  song and stretches its timing to the length of the song that is playing (then fine-tune with Fit). The table keeps
  title, artist, length, language and source, so a shared catalogue could be added later.
- **Quiet when there is nothing to show:** "No lyrics found" and similar messages fade away after a few seconds.
- **Language versions:** when a song exists in several languages under one title (English and Japanese singles), the
  language named in the track or in YouTube's own video title ("-English version-") picks the matching lyrics; a
  Japanese version may contain English lines.
- **Songs vs. videos:** podcasts, episodes and long videos get no lookup; sped-up/slowed uploads have their
  timestamps stretched; incomplete synced lyrics are replaced by a complete copy or filled in from plain text.
- **Instrumental breaks:** a line fades out once it has been sung when a long break follows, and returns with the next one.
- **Karaoke:** word-by-word highlight when NetEase supplies word timing (asked for in the background, also for
  Spotify songs).
- **Audio visualizer:** a 1:1 embed of *Plasma Audio Visualizer* by Luis Bocanegra with all its settings.
- **Look-ahead:** lyrics of the next songs in the (shuffled) queue are fetched in advance (Spotify app,
  YouTube Music through a small Chrome extension).
- **Dynamic:** up to four colours from the album cover, exactly as they are (current line, other lines, and a gradient in
  the visualizer; black, white and grey covers give those greys), one colour or several; hides the neighbouring lines
  when the widget is small, fades out when nothing plays, and pauses all work when a window is full screen or maximized.
- Per-song sync offsets, layered/overlapping lyrics, size modes (free, fixed, full screen width).

## Requirements

| For | Packages |
|---|---|
| Build and run | KDE Plasma 6, `base-devel`, `cmake`, `ninja`, `qt6-base`, `qt6-declarative`, `qt6-websockets`, `icu` |
| Chrome / YouTube | the **Plasma Browser Integration** extension in your browser (for clean title and artist) |
| Accurate Japanese romanization | `python` (the setup script does the rest) |
| Visualizer (optional) | `cava` |
| Spotify lyrics and look-ahead (optional) | Spotify started with a DevTools port (Spicetify enables **8088**) |

```
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava
```

## Install

```
git clone https://github.com/AWeebTaku/lyric-widget lyrics-widget && cd lyrics-widget
./rebuild.sh
```

`rebuild.sh` does a clean cycle each time: sets up the romanization helper (first run only, about 30 s and
270 MB in `~/.local/share/lyric-widget/venv`), wipes the build folder, the cached lyrics and plasmashell's QML
cache, builds, installs into `/usr` with `sudo`, and restarts plasmashell. Your widget settings and your
per-song sync offsets are kept (offsets live in `lyrics.db` next to the cache, which only loses its lyrics table;
`clear-all.sh` removes everything).

Then right-click the desktop, **Add or Manage Widgets**, drag **Lyric Widget** onto it, and play something.
Right-click the widget, **Configure**, for the settings.

Manual build, if you prefer:

```
cmake -B build -S . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
systemctl --user restart plasma-plasmashell
```

Installed files: `/usr/lib/qt6/qml/org/lyricwidget/` (C++ plugin), `/usr/share/plasma/plasmoids/org.lyricwidget/`
(the widget), `/usr/share/lyric-widget/` (Chrome extension and the romanization script).

### Uninstall

```
./clear-all.sh --dry-run    # shows what it would do
./clear-all.sh              # asks for confirmation: removes the widget, installed files, caches and data
```

It keeps this source folder. Remove the Chrome extension yourself at `chrome://extensions`.

## Settings

Right-click the widget, **Configure**. Four simple pages, then two for the visualizer (shown while it is on), all built the same way (headed sections, label on the left, setting on the right):

- **Lyrics**: show lyrics on or off; font, the two text sizes (0 hides that text), bold, colours, colours from the
  album cover (one color or several); what to show (romanized text, previous/next lines, word-by-word highlight, artist and title,
  animation); shift all lyrics in time and optional sync buttons on hover.
- **Layout**: widget size (free, fixed or full screen width; 0 = as small as possible), background, where the lyrics
  sit (3x3 position picker and a pixel shift), the visualizer (on/off, size, position, hide when silent), and when
  the widget hides or stops working (nothing playing, paused, a window full screen or maximized).
- **Lyrics library**: get the lyrics of the playing song from the web, edit the text, stretch or thin out the
  timing, save it (see above).
- **Sources**: use the Spotify app for lyrics and the queue (port + Test), how many next songs to prepare, and
  the YouTube Music queue with one-click help for installing the browser extension.
- **Visualizer style** and **Audio input**: the original Plasma Audio Visualizer pages (style, colours, cava input), laid out like the rest.

## How it works

```
 MPRIS players (Spotify, Plasma Browser Integration)
        |  D-Bus, event driven
        v
 PlayerWatcher --> LyricsController <--> LyricsStore (SQLite cache, per-song offsets, learned sources)
                     |   |   |
   Spotify app ------+   |   +---- timer per line, layered lines, word timing
   (exact lyrics)        |
                         +---- LyricsFetcher: LRCLIB | NetEase | QQ | Kugou  (parallel, scored, merged)
                         +---- ReadingFetcher: UtaTen furigana -> romaji helper (MeCab + UniDic)
 QML: LyricStage (transition), AudioViz (cava + canvas), settings pages
```

- **Matching.** Candidate titles are derived from the player's text (artist「Song」, dash splits, variant
  tags). Each provider result is scored on title, artist, duration and album; weak results are rejected
  (instrumental, karaoke, placeholders, wrong artist). The best-scoring synced result wins, complete copies
  beat copies with a missing verse, and the first answer is shown and upgraded when better data
  (romanization, word timing) arrives. A provider silent for 7 s is left out.
- **Caching.** Settled answers are saved; provider failures and unsynced-only answers are not, and are retried
  quietly. A Japanese/Chinese song saved without provider romanization is looked up again after an hour.
- **Romanization order.** Provider romanization (NetEase, Spotify) first; otherwise UtaTen furigana run
  through MeCab; otherwise MeCab alone. Korean (Revised Romanization) and Chinese (pinyin) are local.
- **Look-ahead.** Up to 5 upcoming songs, one at a time, 5 s apart, never while a window covers the widget.

## YouTube Music queue (Chrome extension)

Browsers do not expose their queue, so a tiny extension (`extension/`, no store listing, talks only to
`127.0.0.1`, runs only on `music.youtube.com`) passes the "Up next" list to the widget.

1. **Configure, Sources**: tick *Receive the YouTube Music queue*, Apply. Check with
   `curl -i http://127.0.0.1:8899/ping`.
2. On the same page click *Open <your browser>'s extensions page*, turn on **Developer mode**, **Load unpacked**,
   and pick `/usr/share/lyric-widget/extension` (use *Copy folder path*; press `Ctrl+L` in the dialog).
3. Open music.youtube.com, reload the tab, play from a playlist, open **Up next** once, then
   `curl -s http://127.0.0.1:8899/status` should list the queue.

If it stays empty: check the extension's service worker console, and on the page run
`document.querySelector('ytmusic-player-queue-item').data` (the extension expects `videoId`, `title`,
`longBylineText`, `lengthText`; YouTube changes its page now and then, so `extension/page.js` may need a tweak).
If you change the port in the widget, change `PORT` in `extension/background.js` too. This extension has not
been tested against a live YouTube Music tab yet.

## Privacy and security

- **Leaves your computer:** lyric searches to LRCLIB, NetEase, QQ Music and Kugou (song title, artist, album,
  length), the song title to UtaTen for Japanese readings, the YouTube video id to YouTube (for the video's title), and the album-art image request to the player's own
  CDN. No account, identifier or telemetry. Kugou is queried over plain HTTP (its certificate does not validate).
- **Local listeners, `127.0.0.1` only:** `8899` (extension receiver, off unless enabled; accepts `POST /queue`
  only from a browser-extension origin with the widget's marker header).
- **Spotify app route:** connects to the app's existing local debug port and runs read-only queries (queue,
  lyrics). A DevTools port is powerful for any local program; keeping it open is your choice.
- **Files:** `~/.local/share/plasmashell/lyrics.db` (cache, offsets and your lyrics library), `~/.local/share/lyric-widget/venv`
  (romanization helper).
- Lyrics belong to their owners and come from third-party services under their own terms.

## Troubleshooting

| Problem | Try |
|---|---|
| No lyrics for a song | `touch ~/.cache/lyric-widget/debug`, restart plasmashell, replay; then `journalctl --user -u plasma-plasmashell -n 300 \| grep -E "netease\|kugou\|publish"` shows each provider's pick |
| Chrome shows `Song \| YouTube Music` with no artist | install/enable **Plasma Browser Integration** |
| Wrong Japanese readings | make sure `./setup-romaji.sh` finished (`romanization: ready`); readings come from UtaTen when it has the song |
| Visualizer blank | check `cava` is installed and audio plays; Settings, Audio input |
| See errors | `journalctl --user -b \| grep -i -E "lyric\|org.lyricwidget"` |

## Known limits

- Some songs have no synced lyrics anywhere; unsynced text is shown as a static block.
- Karaoke needs NetEase word timing; many songs have none.
- Provider APIs are unofficial and can change or rate-limit without notice.

## Project layout

```
CMakeLists.txt  rebuild.sh  clear-all.sh  setup-romaji.sh
src/        C++ plugin (QML module org.lyricwidget): PlayerWatcher, LyricsController, LyricsFetcher, Text.h
            (matching), LyricsStore, ReadingFetcher, SpotifyApp, BrowserQueue, Process, ...
plasmoid/   the widget: metadata.json, contents/ui (main.qml, LyricStage.qml, settings pages, audioviz/),
            contents/config (main.xml settings schema, config.qml pages)
romaji/     romaji.py: MeCab + UniDic helper run in the private Python environment
extension/  Chrome extension (Manifest V3) for the YouTube Music queue
```

## Credits and license

GPL-3.0 (see `LICENSE`). The visualizer files under `plasmoid/contents/ui/audioviz/` are copied from
[Plasma Audio Visualizer](https://github.com/luisbocanegra/plasma-audio-visualizer) by Luis Bocanegra
(GPL-3.0), which is why this project is GPL-3.0 too; see `NOTICE`. Lyric data: LRCLIB, NetEase Cloud Music,
QQ Music, Kugou, Spotify (Musixmatch), UtaTen (readings). Romanization: MeCab, UniDic, fugashi, cutlet, ICU.
