# Your own visualizers, seek bars and buttons

The widget can load a visualizer, a seek bar or a set of playback buttons that you wrote as a QML file.

**These files run as they are, with no sandbox: only use files you trust.** They are off until you turn on
*Settings, Visualizer, Effects, Allow my own QML visualizers*.

Put the files here (create the folders):

| What | Folder | Chosen in |
|---|---|---|
| Visualizer | `~/.local/share/lyric-widget/visualizers/` | Visualizer, Style: *Custom QML file*, then Effects: *Custom visualizer file* |
| Seek bar | `~/.local/share/lyric-widget/progress/` | Card, Seek bar: *My own QML file* |
| Buttons | `~/.local/share/lyric-widget/buttons/` | Card, Buttons: *My own QML file* |

Working examples are installed in `/usr/share/lyric-widget/examples/` (and are in `examples/` in the source).

Each file's root item should fill its parent. The widget gives the root item whichever of the properties below it
declares, and connects whichever of the signals it has. Unknown ones are ignored.

## Visualizer

Properties given: `values` (a list, 0..100 per bar), `peaks` (the falling caps, same scale), `bass`, `mid`, `high` (0..1),
`beat` (1 on a beat, then falling), `colors` (the bar colors).

## Seek bar

Properties given: `position` and `length` (seconds), `playing`, `accent`, `textColor`, `beat`, `chapters` (a list of
`{start, title}` in seconds), `labels` (0 off, 1 elapsed and total, 2 elapsed and remaining).
Signals it may emit: `seekTo(real sec)`, `seekBy(real seconds)`.

## Buttons

Properties given: `playing`, `shuffle`, `loop` (`"None"`, `"Track"` or `"Playlist"`), `accent`, `iconColor`,
`showSkip`, `showShuffleRepeat`.
Signals it may emit: `previous()`, `toggle()`, `next()`, `toggleShuffle()`, `cycleLoop()`.
