# Changelog

Each release's section is used for its GitHub release notes (`.github/workflows/release.yml`), so keep the heading as `## <version>`.

## 2.3.0

- The looks have their own **Looks** page, between Card and Sources. The Visualizer page now starts at Style.
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
