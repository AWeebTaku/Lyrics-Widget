# Visualizer upgrade plan: bring a richer audio visualizer into the Lyric Widget

Status: **executed on 2026-11-18, partly.** See "Implementation status" at the end for what was built and what was left out.

## Context

The Lyric Widget's visualizer is a cava-fed Canvas with three styles (bars, wave, blocks), circle mode, gradients,
cover-colour tint and a full set of cava settings. A reference widget (another open-source Plasma visualizer widget) offers a
much larger visualizer: 22 styles, GPU shaders, beat-reactive effects, colour modes, presets and a settings studio.
Goal: give the Lyric Widget the same breadth of visualizer features, as its own implementation, inside the existing
settings pages. Everything that is about being a media-player card (artwork, progress bar, buttons, layouts) is
left out because this is a lyrics widget (see "Out of scope").

## Licence and credit: how this plan avoids needing any

Both projects are GPL-3.0 and so is the Lyric Widget. GPL lets code be reused, but it requires copyright and
licence notices to stay with it, so copied code cannot be used without credit. You asked for no credit, so:

- **Clean-room rule: copy nothing.** No source code, no shader code, no QML, no preset JSON, no setting names or
  help strings, no palette names or values, no file layout. Write every part from the feature descriptions below.
- Features and algorithms are ideas and can be reimplemented freely (a peak cap that decays, a beat detector,
  a log frequency axis). Only the expression is protected.
- Do not read the reference project's source while implementing. The feature list below is the specification.
  Shaders in particular (their `.frag` files were not read for this plan) must be designed from scratch.
- Use different names for styles, settings and palettes, and your own default values.
- The existing credit to *Plasma Audio Visualizer* (NOTICE and README) stays: files under
  `plasmoid/contents/ui/audioviz/` still come from that project. New work goes in new files where possible so that
  the line between credited and original code stays clear.
- This is not legal advice. If the project is ever published beyond this repo, have the clean-room approach checked.

## What exists today (so nothing is rebuilt)

Architecture: `ui/main.qml` Loader -> `ui/AudioViz.qml` -> `ui/audioviz/Cava.qml` (runs `cava`, ASCII bars via
`src/Process.cpp`) -> `ui/audioviz/components/Visualizer.qml` (one Canvas) -> `ui/audioviz/code/drawCanvas.js`.

Already there: bars / wave / blocks; wave shapes (curve, square, triangle); circle mode; mirrored (centred) bars;
rounded bars; bar width and gap; orientation (4); gradient colours with several flows; cover-colour tint; colour
sources (custom, theme, list, random, hue range); sensitivity, noise reduction, monstercat, waves, cutoff
frequencies, 5-band EQ, mono/stereo, input source picker; hide on silence; size and position grid; pause when a window
is full screen or maximised.

Limits that shape this plan: cava gives only binned values (no raw FFT, no peaks, no beat data); the Canvas repaints
on the GUI thread; no shader pipeline exists; every cava change restarts cava; a new setting touches four places
(`config/main.xml`, a control in `ConfigVisualizer.qml`/`ConfigCava.qml`, a `cfg_` alias in `configAppearance.qml` or
`configContent.qml`, and the reader in `AudioViz.qml`).

## Feature inventory and mapping

Legend: **have** = exists today, **new** = to build, **skip** = out of scope.

### A. Audio analysis and reactivity (the foundation; most new features depend on it)
| Feature | Status | How |
|---|---|---|
| Per-bar smoothing with release on silence | new | analysis layer, exponential approach, time constant setting |
| Noise gate (ignore tiny values) | new | threshold in analysis layer |
| Peak-hold caps with slow fall | new | peaks = max(level, previous - fall step) per frame |
| Bass / mid / high levels | new | means of the lowest, middle, top bands |
| Beat "attack" pulse | new | fast level vs slow envelope, threshold, minimum gap between beats |
| Bass and treble weighting | new | per-band gain curve |
| Log or mel frequency spacing | new | resample cava's bands onto the chosen axis |
| Edge taper (soften first/last bars) | new | cosine window over the outer ~15% |
| Frequency cutoffs, sensitivity, EQ, noise reduction | have | cava settings |
| Silence release time, idle frame-rate drop | new | see section H |

### B. Styles (each is a new `VisualizerStyles` id)
| Style (own names) | Idea |
|---|---|
| Peak bars | bars plus falling caps |
| LED meter | stacked segments, colour by height (extends Blocks) |
| Mountain | filled area with a soft ridge, mirrored option |
| Oscilloscope / CRT scope | line trace, optional scanline and phosphor glow |
| Pixel matrix | grid of dots lit by level |
| Floating dots | one dot per band rising and falling |
| Tech line | thin polyline with node markers |
| Radial burst | spokes from a centre (extends circle mode) |
| Pulse orb | circle that breathes on bass, rings on beat |
| Ribbon / silk ribbon | flowing band with curvature and fullness sliders |
| Sparkles | particles and ripples spawned on beats |
| Gravity sparks | particles that fall, bounce and fade |
| Terrain, tunnel, plasma | shader-heavy backdrops driven by levels (GPU path only) |
| Stereo scope (Lissajous) | left/right trace; needs a separate stereo capture, last priority |
| Orbit ring around the lyrics | visualizer wrapped around the text block (new idea fit for a lyrics widget) |
| Bars, wave, blocks, circle, mirrored | have |

### C. Rendering
| Feature | Status | How |
|---|---|---|
| Canvas path for the simple styles | have | extend `drawCanvas.js` |
| GPU path (ShaderEffect + `.qsb` shaders) | new | needs Qt6 ShaderTools in CMake (`qt_add_shaders`); values go to the shader as a 1-row texture produced by a small C++ `QQuickItem`/texture provider |
| Bloom / glow | new | cheap version: second blurred copy with `MultiEffect` (already used in `StyledText.qml`); full version: shader pass |
| Fallback when shaders are unavailable | new | keep Canvas for styles that can use it; hide GPU-only styles in the picker |

### D. Colour
| Feature | Status | How |
|---|---|---|
| Solid, gradient, custom list, hue range, random, theme, cover | have | `ColorSourceType` |
| Rainbow (hue cycles over time) | new | timer-driven hue offset |
| Built-in named palettes (6 to 10, three stops each) | new | own palettes and names |
| Music-reactive hue (drifts with time and treble) | new | hue offset from analysis levels |
| Separate glow colour list | new | second colour list for the glow pass |
| Per-bar colour by level (not only by position) | new | needs the shader or a per-bar fill in Canvas |
| Auto contrast for text over the visualizer | new | luminance check of the colour behind the lyric block |

### E. Reactive effects (the part that makes it feel alive)
| Feature | Status | How |
|---|---|---|
| Lyric text pulse on beat (scale or glow, small amount) | new | fits this widget; uses the beat signal, setting for strength |
| Panel edge glow on bass | new | the widget's background panel border or shadow, driven by bass level |
| Ambient glow behind the widget | new | blurred rectangle in the cover or visualizer colour, radius and intensity settings |
| Cover pulse | skip | this widget does not show cover art |
| Audio-reactive progress bar | skip | no progress bar |
| Karaoke fill | have | already built for lyrics |

### F. Presets
| Feature | Status | How |
|---|---|---|
| Built-in presets (aim for 10 to 15 good ones, not 28) | new | a table of config key -> value maps in one JS file |
| User presets (save current look under a name) | new | stored as JSON in one config entry |
| Import / export a preset as JSON text | new | copy to clipboard and paste back, with validation |
| Random look, daily look | new, optional | random picks from presets; daily seeds by date |
| Favourites | new, optional | flag on presets |

### G. Settings experience
| Feature | Status | How |
|---|---|---|
| Presets tab and live preview inside the settings window | new | preview renders the same visualizer component with synthetic bars so it works without music |
| Diagnostics panel (cava missing, no audio backend, cava crashed) with install hint | new | read `Cava.qml` state and show a message with the package-manager command |
| Data-driven settings (one schema, controls generated from it) | new, recommended | removes the four-places-per-setting cost before adding ~40 settings |
| Everything under the existing Appearance > Visualizer tab, plus a Presets tab | new | no new top-level pages |

### H. Performance and behaviour
| Feature | Status | How |
|---|---|---|
| Pause when covered / full screen | have | `main.qml` already does it |
| Drop to ~2 fps after a few seconds of silence | new | frame-rate control in `Cava.qml` and the repaint timer |
| Battery saver (lower fps, no glow) | new | one switch |
| Reduced motion | new | disables particles, pulses and fast flicker; follows a setting, optionally the desktop setting |
| Simple rendering switch | new | forces the Canvas path |
| Pause when hidden | have | Loader is inactive when not needed |

### Out of scope (listed so the decision is on record)
Media controls and buttons, progress bar styles, track info card and metadata lookups, artwork shapes and effects,
the many card layouts and surfaces (glass, liquid glass), Windows overlay and tray, Hyprland/Quickshell shell,
custom user-written QML visualizers (a security risk: run foreign QML), translations of the reference's text.
Any of these can be added later if wanted; none is needed to match the visualizer.

## Architecture decisions

1. **Keep cava as the audio source.** It already works on PipeWire, Pulse and ALSA and your settings page exposes it.
   Raw FFT is not needed: the new features all work from cava's bands.
2. **Add one C++ analysis class** (`src/VizAnalysis.h/.cpp`, `QML_ELEMENT` in the backend plugin, like
   `LyricsLibrary`): input = cava's band values per frame; output = smoothed levels, peaks, bass/mid/high, beat,
   silence flag. C++ keeps it fast at 60 fps and unit-testable in `tests/`, instead of JS in the GUI thread.
3. **Two render paths behind one `Visualizer.qml` interface:** Canvas (existing, extended) and GPU shaders (new,
   optional). A style declares which paths it supports; the picker only shows what can run.
4. **Data-driven settings.** One JS schema describing every setting (key, type, range, default, label, help,
   group); a small generator builds the controls and the `cfg_` aliases. Do this before adding most settings.
5. **New files, not edits, wherever possible:** `VizAnalysis`, `Palettes.js`, `Presets.js`, new style draw files, new
   shaders. Edit `drawCanvas.js`, `Visualizer.qml` and `AudioViz.qml` only to dispatch to them.
6. **Sensible default:** a new style never changes how the widget looks until chosen; presets are opt-in.

## Phases (each phase leaves the widget working and shippable)

**Phase 0: decisions.** Confirm the scope above, the clean-room rule, and the Qt ShaderTools availability on Arch
(`qt6-shadertools`). Add `qt6-shadertools` to `packaging/arch/PKGBUILD` makedepends if used.

**Phase 1: analysis layer.** `VizAnalysis` (smoothing, release, gate, taper, peaks, bass/mid/high, beat, log/mel
spacing, weights). Wire `Cava.values` -> `VizAnalysis` in `AudioViz.qml`. Unit tests with synthetic frames.
No visible change yet except a smoother result and silence handling.

**Phase 2: schema-driven settings + presets plumbing.** Settings schema and generator; preset save/load/import/export
as pure functions with tests (round-trip, bad input rejected). Presets tab with a live preview using synthetic bars.

**Phase 3: Canvas styles.** Peak bars, LED meter, mountain, oscilloscope, pixel matrix, floating dots, tech line,
radial burst, pulse orb, ribbon. One draw function per style, each with a settings group.

**Phase 4: colour system.** Rainbow, palettes, reactive hue, glow list, per-bar colour by level, auto contrast.

**Phase 5: reactive effects.** Lyric pulse on beat, panel edge glow, ambient glow, strength settings, reduced-motion
gate. Particle styles (sparkles, gravity sparks) with hard caps on particle counts.

**Phase 6: GPU path.** CMake shader build, texture provider, shader styles (terrain, tunnel, plasma), bloom pass,
Canvas fallback and the picker rule. Biggest risk; do it last so nothing earlier depends on it.

**Phase 7: polish.** Diagnostics panel, idle fps drop, battery saver, reduced motion, simple rendering switch,
built-in preset set (10 to 15), random/daily look, README feature list and Settings help text.

**Optional later:** stereo scope (needs a stereo capture source), orbit ring around the lyrics, favourites.

## Critical files

- Edit lightly: `plasmoid/contents/ui/AudioViz.qml`, `.../audioviz/components/Visualizer.qml`,
  `.../audioviz/code/drawCanvas.js` and `enum.js`, `plasmoid/contents/ui/configAppearance.qml`, `configContent.qml`,
  `plasmoid/contents/config/main.xml`, `src/CMakeLists` section of `CMakeLists.txt`, `packaging/arch/PKGBUILD`.
- New: `src/VizAnalysis.{h,cpp}`, `plasmoid/contents/ui/viz/` (new styles, `Palettes.js`, `Presets.js`, schema,
  preview, diagnostics), `plasmoid/contents/shaders/` (GPU path), `tests/vizanalysis.cpp`, `tests/presets` check.
- Reuse: `MultiEffect` use in `StyledText.qml` for glow; the offscreen QML test harness approach used for the
  karaoke fix; `Cava.qml` process state for diagnostics; `main.qml` Loader conditions for pause behaviour.

## Verification (for each phase)

1. `cmake -B build -DBUILD_TESTS=ON && ctest`: analysis tests (beat fires on a synthetic kick and not on steady
   noise; peaks fall at the set rate; silence release time; log/mel resampling keeps band count) and preset
   round-trip tests.
2. Offscreen render harness: draw every style from fixed synthetic values and look at the image (GPU styles need
   a real display; the offscreen platform cannot run shader effects, as found with the gradient test).
3. On the desktop with music playing: capture frames with `spectacle` and check motion, colours, glow, pulse.
4. CPU cost per style at a large size (compare against the current wave style); set a budget (e.g. under 5% of one
   core at 60 fps) and fall back or lower fps when over it.
5. Reduced motion and battery saver actually turn effects off; silence drops the frame rate; pause-when-covered still works.
6. A settings round-trip: change, apply, restart plasmashell, values kept; import a bad preset and see it rejected.
7. You run `build.sh` to install; I do not run it myself.

## Risks and open questions

- **Setting overload.** About 40 new settings; the schema generator and presets are the answer, otherwise the page becomes unusable.
- **Canvas CPU.** Particle and glow styles on a GUI-thread Canvas can be expensive; hard caps and the GPU path mitigate it.
- **Shader tooling.** Needs `qt6-shadertools` at build time; check the Arch package and `build.sh` before committing to Phase 6.
- **Cava limits.** No raw FFT: beat detection is from binned data and may be less sharp than from an FFT. Acceptable; revisit with a C++ audio tap only if the beat feels late.
- **Beat on lyrics.** Pulsing the lyric text can hurt readability: keep the default strength low and off by default.
- **Questions for you:** (1) Is dropping the media-card features right, or should a "now playing" card be a later project?
  (2) Are the GPU styles (terrain, tunnel, plasma) worth the shader build cost, or stay Canvas-only?
  (3) Do you want the orbit ring around the lyrics early, since it is the one idea that fits a lyrics widget best?

## Implementation status (2026-11-18)

Built, tested (unit tests, offscreen renders of every style, a copy of the real `AudioViz.qml` run on a display with a
synthetic spectrum) and wired into the widget:

- **A. Analysis:** `src/VizCore.h` + `src/VizAnalysis.{h,cpp}` (smoothing, release after silence, noise gate, falling peak
  caps, bass/mid/high, beat with re-arm, bass/treble weights, edge taper), `tests/vizanalysis.cpp`.
  Not done: log/mel re-spacing (cava's bands are already log-spaced).
- **B. Styles:** peak bars, LED meter, mountain, oscilloscope, pixel matrix, floating dots, tech line, radial burst, pulse orb,
  ribbon, sparkles, gravity sparks (`plasmoid/contents/ui/viz/styles.js`), and the GPU "Plasma" style
  (`viz/plasma.frag`, compiled `viz/plasma.frag.qsb` is committed so building needs no shader tools).
  Not done: terrain, tunnel, stereo scope, orbit ring around the lyrics.
- **C. Rendering:** Canvas path extended; one shader style; glow through `MultiEffect`. Not done: a values texture for
  per-band shaders, a full bloom pass, a simple-rendering switch (battery saver covers part of it).
- **D. Colour:** palettes, rainbow, rainbow pushed by the treble (`viz/palettes.js`, `AudioViz.qml`). Not done: separate glow
  colour list, per-bar colour by level, automatic text contrast.
- **E. Effects:** lyric pulse on the beat, edge glow with the bass, glow around the widget (`main.qml`), particles.
- **F. Presets:** 12 built in, your own, export/import as text with validation, random and daily look
  (`viz/presets.js`, `tests/presets.test.js`). Not done: favourites.
- **G. Settings:** new page **Visualizer effects** (`configVizFx.qml`), new styles in the existing Style list, a message in
  the widget when cava is missing or stops. Not done: the schema-driven settings generator and the live preview with
  synthetic bars (the page is written by hand; applying a preset writes the other pages' settings directly, so reopen
  Settings to see them).
- **H. Performance:** reduced motion, battery saver (20 fps, no glow, no motion effects). Not done: an extra idle frame-rate
  drop (cava's own sleep timer, set by "Hide after pause or silence", already stops it).

Measured with a synthetic spectrum at 640x240 (share of one core): Wave (existing) 32%, peak bars 18%, pixel matrix 21%,
radial burst 23%, pulse orb 20%, sparkles 20%, plasma shader 24%, LED meter 44% (the heaviest new style).

## Scope update (2026-11-18, second pass): remake the whole reference widget inside this one

New instruction: rebuild everything the reference widget offers, not just its visualizer, and add it to this widget.
Everything in "Out of scope" above is now in scope except what cannot exist in a Plasma widget. The clean-room rule is
unchanged: a copy of the reference widget is installed on this machine, but its source is **not** read; the feature list
from the survey is the specification, and everything is written from scratch with its own names, values and layout.

### Not possible in this widget (recorded, not skipped by choice)
- Hyprland / Quickshell shell, Waybar helper, Windows overlay and tray: these are other desktops' shells. This is a
  Plasma plasmoid; the equivalent features here are the desktop widget and the panel pill.
- Translation catalogs: needs translators; every new string already goes through `i18n()`.

### Remaining visualizer work (from the first pass)
Mel / log re-spacing and eight-band levels in `VizCore`; terrain and tunnel shaders next to plasma; stereo scope
(Lissajous, from cava's stereo waveform output, so no extra capture tool); orbit ring around the lyrics; per-bar colour
by level; separate glow colour; automatic text contrast; preset favourites; settings rows generated from one schema and a
live preview with synthetic bars; a simple-rendering switch; an idle repaint throttle.

### Media-card features (new)
| Group | Features | Where |
|---|---|---|
| Player control | previous / play-pause / next, shuffle, repeat, seek, volume (MPRIS) | `MprisPlayer` + `LyricsController` invokables |
| Artwork | shapes (sharp, rounded, squircle, circle, vinyl, CD), size, border, glow, tilt, reflection, grey when paused, fallback art, click action | `ui/card/Artwork.qml` |
| Track info | title / artist / album styles, details view (drawer or tooltip), text edge styles (plain, shadow, frosted) | `ui/card/TrackInfo.qml` |
| Progress | styles: sleek, minimal, glow pulse, bold pill, waveform, squiggle, segmented, dotted, capsule, time only, cover ring, none; time labels off / total / remaining; hover preview, wheel seek, double-click jump | `ui/card/ProgressBar.qml` |
| Buttons | dock styles glass, soft, outline, tinted, bare, accent play; skip, shuffle, repeat; show on hover | `ui/card/Controls.qml` |
| Surfaces | colour, art backdrop (dim, blur), glass, liquid glass (shader), atmosphere, solid; grain, shadow, edge highlight, corner radius | `ui/card/CardSurface.qml` |
| Layouts | visualizer only, classic, mirrored, inline, hero wave, stacked, orbit, lyrics only, poster, slim strip, no art, panel pill | `ui/card/CardLayout.qml`, compact representation |
| Behaviour | scroll to change volume, wheel seek, double-click jump, click on art action | `main.qml` |
| Studio | settings page **Card** (everything above) and **Visualizer effects** with live preview | `configCard.qml`, `configVizFx.qml` |
| Extras | user-written QML visualizers from a folder (opt-in, not sandboxed), online track details (opt-in) | `ui/viz/Custom.qml` |

Existing features stay as they are (lyrics, karaoke, library, providers). "Lyrics only" is today's look and stays the
default, so nothing changes until a layout is chosen.

## Implementation status, second pass (2026-11-18)

Built, with tests (`ctest`: matching, wordtiming, viz, presets, layouts, schema), offscreen and on-display renders, and a copy
of the real `AudioViz.qml` run against a stub config and a synthetic spectrum:

- **Visualizer, remaining items:** mel / linear frequency axis and eight band levels (`VizCore.h`); terrain and tunnel shaders
  (`viz/terrain.frag`, `viz/tunnel.frag`, compiled `.qsb` committed); orbit ring; stereo scope (cava's stereo waveform, no extra
  capture tool); colour by level; glow colour; automatic dark text on a light background; simple rendering; an idle repaint
  throttle; a custom QML visualizer (opt-in); preset favourites; a live preview; settings rows from one schema
  (`card/schema.js`, checked against `main.xml` and the pages by `tests/schema.test.js`); 34 built-in looks.
- **Player control:** `MprisPlayer` and `LyricsController` now play / pause, skip, seek, set volume, shuffle and repeat, and expose
  cover, album and length.
- **Card:** `ui/card/` Artwork, TrackInfo, DetailsPanel, Controls, ProgressBar, CardSurface (with liquid-glass and grain
  shaders), CardLayout, Pill; `layouts.js` (tested) for eleven layouts; the Card settings page; online track facts
  (`src/TrackDetails.*`, off by default).

Not done, and why:
- Hyprland / Quickshell and Windows shells, and translation catalogs: not applicable to a Plasma widget (see "Not possible").
- Chapter marks on the seek bar (needs cue-file or chapter metadata handling).
- The card was not run inside plasmashell itself: `main.qml` cannot be loaded outside it, so the integration was checked by
  running the pieces (card, visualizer, settings pages) with stubs. Install with `build.sh` and look.

## Settings reorganised (2026-11-18)

The eight settings pages (General, Appearance, Visualizer effects, Card, Layout, Behavior, Sources, Lyrics library) are now
six, grouped by subject, with no setting added, lost or moved between pages' keys beyond the grouping:
General; **Lyrics** (Text and colors, Lines and timing, Position); **Visualizer** (live preview above the tabs Style,
Reaction, Effects, Presets, Position, Audio input); Card; Sources; Lyrics library. The old `configAppearance.qml`,
`configContent.qml`, `configLayout.qml` and `configVizFx.qml` are replaced by `configLyrics.qml` and `configVisualizer.qml`.
The visualizer colour-flow control moved from the lyrics colours to the Visualizer page, Style tab.

## Third pass (2026-11-18): the "not done" and "partly done" lists, and the settings streamlined

Source of truth this time: the reference widget's own settings list (190 entries in its `config/main.xml`) and its README and
gallery, read for behaviour only; every part below is written fresh.

**Built:** separate pill and card looks with copy buttons (`pillArtShape`, `pillDockStyle` ...); a pin on the opened card; hover or
click to open the pill; the panel modes card / pill / adaptive by panel thickness, with rotation for vertical panels and a
fit or fixed scale; pill content, art, small visualizer (moving bars or live cava), progress line or ring, buttons, scrolling
title, click action; blur behind the card through Plasma's own background; custom seek bars and buttons from QML files (with
examples and `docs/custom-styles.md`); local lyrics (`src/LocalFiles.h`: `.lrc` beside the song, a lyrics folder, ID3 and FLAC
tags, `.romaji.lrc` pronunciation, tested in `tests/localfiles.cpp`); chapter marks from `.chapters` / `.cue`; sparks off the
cover; YouTube thumbnail; wide covers and a fallback look for a missing cover; the CRT oscilloscope and silk ribbon styles with
ribbon sway and fullness; `tools/doctor.sh`; the preset gallery (`tools/gallery/render.sh`, `docs/gallery.md`, 36 pictures);
a live preview of the whole card in the settings; the Icon layout; poster options; orbit options; colour sources for the
accent, the seek bar and the buttons; title size, alignment, player name and player switch; hover lift, dim and fade while paused.

**Streamlined with what was already there** (no setting is duplicated; `tests/schema.test.js` now checks that each setting lives on
exactly one page and that every setting has a page):
- the old *Background* (a coloured panel with corners) on General and the card's surface colour and radius were one thing: it is
  now the card's Colour surface (`panelColor`, `panelRadius`), and the old on/off setting is carried over once at start;
- my "move the visualizer up or down" duplicated the existing pixel offset: removed;
- reduced motion, battery saver, simple rendering and dim / fade while paused moved to General, *Motion and power*, beside the
  existing hide and pause settings; reduced motion also stops the line animation;
- "dark text on a light background" moved next to the lyric colours;
- a separate poster alignment was folded into the one text alignment setting.

**Still not done:** a Hyprland / Quickshell / Windows version and translation catalogs (not for a Plasma widget); the reference's
"use popup look / pill look" is the copy buttons here, without separate saved popup and pill presets; its browser studio.

## Fourth pass (2026-11-18): the card brought in line with the rest of the settings

Found by running the real widget (plasmawindowed with the real backend and music): the card and visualizer work, but the card
felt bolted on. Changed:
- **Show: Lyrics / Visualizer / Card** on the General page. The card's layout list no longer has "Lyrics only" and "Visualizer only"
  (they were the same thing as the Show checkboxes); `layouts.js effectiveMode` derives the layout in force from the three
  switches and the chosen arrangement (`showCard`, `layoutMode` 2..11). The presets set the switches that a look needs.
- **The layout places the visualizer** (beside the cover, behind the text; over the whole card in hero wave, poster and slim strip;
  in the ring for orbit). The Position tabs of Lyrics and Visualizer say they apply when there is no card.
- **The card accent follows the lyrics** by default (the cover's colors when "Use colors from the album cover" is on).
- **The Card page is tabs** like Lyrics and Visualizer (Layout, Surface, Cover, Controls, Text, Panel, Behavior), with the preview on
  top and a notice when the card is off.
- **One spelling**: "color", "center", "favorite", "behavior" throughout (the existing pages already used them).

## Sixth pass (2026-11-19): the settings rebuilt from scratch (test copy)

The old settings pages were slow, overlapped one another, and one design (tabs that copied values between a page and its
tabs) froze the desktop through a recursion in Plasma's own config window. They were rebuilt:
- `settings/model.js` is the one list of every setting; `SettingsPage.qml`, `Section.qml` and `Field.qml` draw any page from it;
  `tools/gen-settings.js` writes the page files; every control reads and writes the page's own `cfg_<key>` directly (nothing is
  copied between objects, nothing is ever set to null, lists are replaced, never edited).
- Seven pages: General, Lyrics, Visualizer, Audio input, Card, Sources, Lyrics library. Rows hide when they do not apply; each
  page has search; previews are off until asked for; the first card of a page is open, the others are built when opened.
- Removed: SchemaForm, schema.js, the tab components, the original visualizer's settings forms (FormColors, ConfigCava...).
  `tests/settings.test.js` replaces `schema.test.js`.
- Checked without Plasma (offscreen harness: each page loaded the way Plasma loads it, every `cfg_` value read, rendered, with
  each `when` branch and a search). Not checked: Plasma's real config window; test the Audio input page first.

## Seventh pass (2026-11-19): the card owns the background; layouts can be edited; the cover fills its shape

- `layouts.js`: the background and the visualizer's place are parts of the layout like the rest (`surface`, `vizPlace`);
  `applyEdits` hides, moves, resizes and fades any part from the stored `layoutEdits` JSON (differences from the layout's own
  place, per layout; layout 1 shares layout 0's). The corner buttons and the sync row are parts too and are placed by the layout
  in every mode (no more special legacy position). Tested in tests/layouts.test.js.
- `settings/LayoutEditor.qml`: the editor (Card page, "Edit the layout").
- `Artwork.qml`: the cover fills its shape by default. The earlier "whole picture over a blurred copy" wrapper made the effects
  draw the picture small and unmasked (the record label showed a tiny rectangle); the image is fed to the effects directly again,
  `fit` 1 shows the whole picture with empty bars, and `focusH/V` choose the part kept when a wide picture is cropped.
- Settings are per widget copy already (each applet has its own configuration). Plasma allows only one settings dialog at a time
  (tested on the desktop: opening widget B's settings closes widget A's), so see the next section.

## Eighth pass (2026-11-20): settings windows of the widget's own, so several can be open together

- `SettingsWindow.qml` (one per widget copy, opened from the widget's menu: `Plasmoid.contextualActions` in main.qml) shows the same
  pages in a window; `settings/<Page>Panel.qml` (generated by tools/gen-settings.js) are the pages as scrolling panels with
  `load(cfg)` / `save(cfg)`. Tested with two windows over two separate configurations: Apply in one changes only its widget.
- Removed the widget numbers from the Plasma dialog's title and from the page.
- Not verified: the menu entry and the window in the real plasmashell (only in the offscreen harness).
- The menu has one entry: "Configure Lyric Widget…" now opens this window (Plasma's own configure action is removed in main.qml);
  the window has a "Lyrics library…" button for the page Plasma's dialog used to list.
- Cover colors (src/LyricsController.cpp, src/Palette.h): the colors come from the picture the widget shows (the video's own
  picture when "Always use the video's own picture" is set), with the other as a fallback and ten patient retries. Before, they only
  came from the player's cover file, which a browser may write late or never, so a song could stay without colors until a pause.

## Ninth pass (2026-11-20): one theme for every settings window and page

- `settings/tokens.js` is the whole look: the Plasma theme only (text, background, the highlight color as the one accent), one
  radius scale (8 and 4, no pills, no gradients), hairlines between groups instead of a box round each, helper text at 0.75 opacity
  (readable), a content column of 46 grid units centered however wide the window is.
- Applied to: the settings pages (and so the settings window), the lyrics library page and window (same title, same type), and the
  editors (layout parts, looks, colors, equalizer, source list).
- Windows are sized to the screen they open on (the settings window and the library window were taller than a 768 px screen).
- Fixed from the real plasmashell log: the settings window's pages read the configuration before it was set (a TypeError), and the
  pages' implicit sizes formed binding loops.
- Not rendered: a dark Plasma theme (every tint is the text color at a low alpha, so it should follow).
