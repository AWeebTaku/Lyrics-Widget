## Lyric Widget {{VERSION}}

Synced lyrics, an audio visualizer and a media card for Spotify and YouTube Music on KDE Plasma 6.

### What is in this version

{{CHANGES}}

### Install (one file, does everything)

```
curl -fsSLO https://github.com/AWeebTaku/Lyrics-Widget/releases/latest/download/lyric-widget.sh
bash lyric-widget.sh              # download, build and install the latest release
bash lyric-widget.sh check        # is there a newer release?
bash lyric-widget.sh update       # install it
bash lyric-widget.sh uninstall    # remove the widget (add --purge to delete your lyrics library too)
```

`--dry-run` shows what any command would do, `-y` skips the questions. Packages are installed for you on Arch Linux; on other
systems the script lists what is missing. The checksums are in `SHA256SUMS`.
