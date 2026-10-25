# Lyric Widget for KDE Plasma 6

Synced lyrics on your desktop for **Spotify** and **YouTube / YouTube Music in Chrome**, with
romanization, karaoke highlighting, an embedded audio visualizer and look-ahead for shuffled queues.
A native Plasma widget: QML for the interface, a C++ plugin for everything else.

> Status: personal project, developed and tested on Arch Linux with Plasma 6 and Qt 6.12. There is no
> automated test suite; features were checked by hand against real songs. Issues and patches welcome.

## Features

- **Timed lyrics** for the song playing, switching line by line from the player's position (one precise
  timer per line, nothing polling), with a smooth swipe-and-fade between lines scaled to the song's pace.
- **Many sources, matched carefully.** Spotify songs are first asked of the Spotify app itself (exact, by
  track id). Otherwise LRCLIB, NetEase, QQ Music and Kugou are searched in parallel and scored on title,
  artist, length and album, with cross-script matching (`ヨルシカ` = `Yorushika`). No accounts or keys.
- **Romanization replaces the original line** (Japanese, Korean, Chinese) when available: provider
  romanization, human-made furigana from UtaTen, or a local MeCab/UniDic converter.
- **Songs vs. videos:** podcasts, episodes and long videos get no lookup; sped-up/slowed uploads have their
  timestamps stretched; incomplete synced lyrics are replaced by a complete copy or filled in from plain text.
- **Karaoke:** word-by-word highlight when NetEase supplies word timing.
- **Audio visualizer:** a 1:1 embed of *Plasma Audio Visualizer* by Luis Bocanegra with all its settings.
- **Look-ahead:** lyrics of the next songs in the (shuffled) queue are fetched in advance (Spotify app,
  YouTube Music through a small Chrome extension).
- **Optional audio listening** (off by default): tempo-matched animation, beat pulse, timing check.
- **Dynamic:** colours from the album art, hides or compacts itself when there is no room or nothing plays,
  pauses all work when a window is full screen or maximized.
- Per-song sync offsets, layered/overlapping lyrics, size modes (free, fixed, full screen width).

## Requirements

| For | Packages |
|---|---|
| Build and run | KDE Plasma 6, `base-devel`, `cmake`, `ninja`, `qt6-base`, `qt6-declarative`, `qt6-websockets`, `icu` |
| Chrome / YouTube | the **Plasma Browser Integration** extension in your browser (for clean title and artist) |
| Accurate Japanese romanization | `python` (the setup script does the rest) |
| Visualizer (optional) | `cava` |
| Audio listening (optional) | `libpulse` (provides `parec`) |
| Spotify lyrics and look-ahead (optional) | Spotify started with a DevTools port (Spicetify enables **8088**) |

```
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative qt6-websockets icu python cava libpulse
```

## Install

```
git clone https://github.com/AWeebTaku/lyric-widget lyrics-widget && cd lyrics-widget
./rebuild.sh
```

`rebuild.sh` does a clean cycle each time: sets up the romanization helper (first run only, about 30 s and
270 MB in `~/.local/share/lyric-widget/venv`), wipes the build folder, the lyrics cache and plasmashell's QML
cache, builds, installs into `/usr` with `sudo`, and restarts plasmashell. Your widget settings are kept; the
cache file also holds your per-song sync offsets, so those are reset with it.

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

### Lyrics
Font, sizes, bold, colours; show romanization; show previous/next lines (hidden automatically when the widget
is small); line animation; karaoke; colour the current line (and optionally the visualizer) from the album art;
header line; global sync offset; per-song sync buttons on hover. **Listen to the audio** (off): tempo-matched
animation, beat pulse, and an experimental check of the lyric timing against the singing.

### Widget
Size (free / fixed pixels / full screen width), background panel, hide when idle, fade out after N minutes
paused, pause everything while a window is full screen (default) or maximized.

### Visualizer, Visualizer style, Audio input (CAVA)
Master switch and height, plus the original Plasma Audio Visualizer pages (styles, colours, gradients, wave
and circle modes, cava input, smoothing, equalizer, frame rate). The style pages appear when the visualizer
is on.

### Accounts
Look-ahead count (0-5), the Spotify app route (on by default; a **Test** button checks it), the YouTube Music
receiver with one-click help for installing the extension, and an optional Spotify account route.

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
                         +---- AudioListener: parec -> loudness curve, beats, tempo (optional)
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

1. **Configure, Accounts**: tick *Receive the YouTube Music queue*, Apply. Check with
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
  length), the song title to UtaTen for Japanese readings, and the album-art image request to the player's own
  CDN. No account, identifier or telemetry. Kugou is queried over plain HTTP (its certificate does not validate).
- **Local listeners, `127.0.0.1` only:** `8899` (extension receiver, off unless enabled; accepts `POST /queue`
  only from a browser-extension origin with the widget's marker header) and `8898` (only while connecting a
  Spotify account, about 3 minutes).
- **Spotify app route:** connects to the app's existing local debug port and runs read-only queries (queue,
  lyrics). A DevTools port is powerful for any local program; keeping it open is your choice.
- **Audio listening:** reads the output monitor (never the microphone) through `parec`, only while playing
  and visible; only loudness numbers are kept, nothing is recorded or sent. It hears everything that plays.
- **Files:** `~/.local/share/plasmashell/lyrics.db` (cache and offsets), `spotify.json` (mode 0600, only if you
  connect an account), `~/.local/share/lyric-widget/venv` (romanization helper).
- Lyrics belong to their owners and come from third-party services under their own terms.

## Troubleshooting

| Problem | Try |
|---|---|
| No lyrics for a song | `touch ~/.cache/lyric-widget/debug`, restart plasmashell, replay; then `journalctl --user -u plasma-plasmashell -n 300 \| grep -E "netease\|kugou\|publish"` shows each provider's pick |
| Chrome shows `Song \| YouTube Music` with no artist | install/enable **Plasma Browser Integration** |
| Wrong Japanese readings | make sure `./setup-romaji.sh` finished (`romanization: ready`); readings come from UtaTen when it has the song |
| Visualizer blank | check `cava` is installed and audio plays; Settings, Audio input (CAVA) |
| See errors | `journalctl --user -b \| grep -i -E "lyric\|org.lyricwidget"` |

## Known limits

- Some songs have no synced lyrics anywhere; unsynced text is shown as a static block.
- Karaoke needs NetEase word timing; many songs have none.
- Automatic timing correction from the audio is experimental and conservative.
- The Spotify Web API (account) route has not been tested against a real account.
- Provider APIs are unofficial and can change or rate-limit without notice.

## Project layout

```
CMakeLists.txt  rebuild.sh  clear-all.sh  setup-romaji.sh
src/        C++ plugin (QML module org.lyricwidget): PlayerWatcher, LyricsController, LyricsFetcher, Text.h
            (matching), LyricsStore, ReadingFetcher, AudioListener, SpotifyAccount, BrowserQueue, Process, ...
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
