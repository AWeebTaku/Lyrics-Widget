# Prompt: finish the settings revamp (run in this directory, /home/adu/Projects/Lyrics-Widget-test)

Copy everything below the line into a new Claude Code session started in this directory.

---

You are continuing a rebuild of the Settings pages of this KDE Plasma 6 lyrics widget. This directory is a test copy of the
project (the main directory, /home/adu/Projects/Lyrics-Widget, was reset to GitHub's original on purpose: do not touch it).
Work only here. Do not commit or push unless asked. Do not run build.sh, uninstall.sh or any sudo script. Do not write to the
user's lyrics library or database. Never credit the "audio-wave-visualizer" project in new text or files.

## Why a rebuild
The old settings pages (configGeneral/Lyrics/Visualizer/Card/Audio/Accounts.qml plus SchemaForm, PageHeader, PillTab,
PanelStack, LazyTab, audioviz/ConfigVisualizer.qml, ConfigCava.qml, FormColors) were slow, had overlapping settings, and one
design (lazy tabs that copied values between a page and its tabs) froze the user's desktop: Plasma's config window recurses
until the stack overflows if a `cfg_` value goes null or two objects keep setting each other. The new design has no such
copying: every control reads and writes the page's own `cfg_<key>` property directly.

## What exists (in plasmoid/contents/ui/settings/, all pass qmllint, none loaded in a test window yet)
- `model.js`: every setting defined once (pages, sections, rows). The row types and `when` rules are documented at the top.
  All settings in config/main.xml are on exactly one page, except `showPanel` and `debugMode` (no page, on purpose).
- `Field.qml` (one row; picks a control by type), `Section.qml` (collapsible card, Reset button, search matching),
  `ColorSwatch.qml`, `AlignPicker.qml`, `EqEditor.qml`, `ColorSpec.qml` (visualizer color setup stored as JSON).
- Field.qml already refers to these components that DO NOT EXIST YET: `SourceField`, `PresetsPanel`, `SpotifyCheck`,
  `BrowserSetupRow`, `SitesList`.

## Remaining work, in order
1. Write the missing components in settings/:
   - `SettingsPage.qml`: a `ColumnLayout` root with `required property var kcm` (the page) and `required property string pageId`.
     Header (icon tile, title, subtitle), the optional `banner` from the model (text + a button that sets
     `Plasmoid.configuration[banner.key] = true`), a search box (lower-cased query passed to every Section), an optional
     "Show a live preview" switch that is OFF by default (pages with `preview: "viz"` or `"card"`; load
     `../viz/VizPreview.qml` or `../card/CardPreview.qml` by file name in a Loader only when on; settings for the preview =
     the page's `cfg_` values over `Plasmoid.configuration`, over the keys of `viz/presets.js` `Presets.keys` and the page
     keys; CardPreview takes `forceCard: true`, `s`, `viz`, `accent`; VizPreview takes `s`, `still`), then a Repeater of
     `Section`s. Section 0 starts open (`open: true` in the model).
   - `PresetsPanel.qml`: the visualizer looks manager, ported in behavior from the old Presets tab (see the old
     configVisualizer.qml in git history, `git show HEAD:...` does not have it; the untracked old file is gone, so read the
     logic from viz/presets.js: `Presets.all/saveUser/deleteUser/toggleFav/randomPick/dailyPick/exportText/importText`).
     Select a look, Apply (writes each key into `kcm["cfg_"+k]` when the page has it, always into `Plasmoid.configuration[k]`,
     then `Plasmoid.configuration.writeConfig()`), favorite star, delete (user looks only), random look, look of the day,
     save current look as a name, share box with Export (copies to clipboard) and Import. It owns `cfg_vizUserPresets` and
     `cfg_vizFavourites` (strings, on the Visualizer page).
   - `SourceField.qml`: a text field for `inputSource` plus a "Choose from the list" button that, only when pressed, runs
     `pactl list sources short && pactl list sinks short` (use `../audioviz/components/RunCommand.qml`) and shows the names
     in a short list; clicking one picks it. Emits `picked(string)`.
   - `SpotifyCheck.qml` (`SpotifyApp` from `org.lyricwidget`: set `debugPort = kcm.cfg_spotifyDebugPort`, `probe()`, show
     `appStatus`), `BrowserSetupRow.qml` (`BrowserSetup`: browser combo from `setup.browsers`, Install extension via
     `setup.openExtensions(b.exec, b.scheme)`, copy path, show folder; port it from the old Sources page behavior),
     `SitesList.qml` (checkboxes for YouTube, YouTube Music, Spotify web, Apple Music web, SoundCloud, Tidal, Deezer,
     Bandcamp that add or remove their hosts in the comma separated `cfg_allowedSites`; hosts: youtube www.youtube.com
     youtube.com; ytm music.youtube.com; spotify open.spotify.com; apple music.apple.com; soundcloud soundcloud.com; tidal
     tidal.com listen.tidal.com; deezer www.deezer.com deezer.com; bandcamp bandcamp.com).
2. Write `tools/gen-settings.js` (node): reads settings/model.js (`new Function` after removing `.pragma library`) and
   config/main.xml, and writes one page file per model page: general -> configGeneral.qml, lyrics -> configLyrics.qml,
   visualizer -> configVisualizer.qml, audio -> configAudio.qml, card -> configCard.qml, sources -> configAccounts.qml.
   Each file: a header comment "GENERATED, do not edit", imports (QtQuick, org.kde.kcmutils as KCM, org.kde.plasma.plasmoid,
   "settings", "wide.js" as Wide), `KCM.SimpleKCM { id: page; Component.onCompleted/Window.onWindowChanged: Wide.grow(Window.window,
   Kirigami.Units.gridUnit); property <type> cfg_<key> and cfg_<key>Default for every key of the page (Bool->bool, Int->int,
   Double->real, String->string, StringList->var); SettingsPage { kcm: page; pageId: "<id>" } }`. Keep configLibrary.qml as it
   is. Update config/config.qml to list: General, Lyrics, Visualizer, Audio input, Card, Sources, Lyrics library.
3. Delete the old settings code: card/SchemaForm.qml, card/schema.js (check `grep` first: viz/ and card/ previews must not
   import it), PageHeader.qml, PillTab.qml, PillTabBar.qml, PanelStack.qml, LazyTab.qml, ColorField.qml, ColorFlowBox.qml,
   FontField.qml, AlignGrid.qml, audioviz/ConfigVisualizer.qml, audioviz/ConfigCava.qml,
   audioviz/components/{FormColors,ColorButton,ColorPickerList,DoubleSpinBoxCompat,PactlList,Eq}.qml. Keep SecondsSpinBox.qml
   (the library editor uses it), wide.js, RunCommand.qml, and every drawing/preview file. Fix any dangling import.
4. Tests: replace tests/schema.test.js with tests/settings.test.js and register it in CMakeLists.txt (same place as the old
   `schema` test). Check: every row key exists in main.xml with a compatible type (bool/int/real/combo/color/text/file/font/flow/
   palette -> Bool/Int/Double/Int/String...), combo defaults fall inside options (or `values`), int defaults inside min..max,
   every `when.key` exists, each key on exactly one page, only showPanel and debugMode on none, and every generated page
   declares exactly its model's `cfg_` keys (and `Default` twins).
5. Verify without Plasma (it cannot be run here): in the scratchpad build a harness that copies plasmoid/contents/ui, replaces
   `Plasmoid.configuration` with a generated `Cfg` singleton from main.xml, loads each configX.qml with `qml6` offscreen
   (QT_QPA_PLATFORM=offscreen), renders it with grabToImage, and for every `cfg_` property on the page reads it and calls
   `toString()`, reporting anything null, undefined (except `cfg_eq` which Plasma fills in) or throwing. Look at the images of
   every page, with sections opened, each `when` branch (e.g. visualizerStyle 1, card layout 8), and a search for "glow".
   Time the page creation: no page may take more than about 150 ms to open on that harness.
6. Run: `node tests/*.test.js`, `cmake -S . -B <scratch>/bt -DBUILD_TESTS=ON && cmake --build <scratch>/bt && ctest`,
   `qmllint` on every qml file. Update README.md (settings section) and VISUALIZER-PLAN.md.
7. Report honestly: what was verified, what could not be (Plasma's real config window), and give the user commit commands
   without a co-author line. Tell them to run build.sh themselves and to test the Audio input page first, since an earlier
   design froze the desktop there.

## Rules that must not be broken
- No page may copy values between objects with `Changed` handlers; no `cfg_` property may ever be set to null/undefined; lists
  (`cfg_eq`) are replaced by a new array, never edited in place.
- Settings keys and saved values in config/main.xml do not change (users' saved settings must keep working).
- American spelling in user-visible text ("color", "center", "favorite"). One name per setting. Each part of the widget owns its
  own settings: Lyrics (how lines look), Visualizer (style/colors/reaction), Card (arrangement, surface, cover, buttons, seek
  bar), General (what shows, size, power), Audio input, Sources.
- When the user asks to find lyrics for a song, treat it as an edge case: fix the rules in general and add a test
  (see src/Text.h `isBanner` and tests/matching.cpp for the latest example).
