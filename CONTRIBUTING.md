# Contributing

Thanks for helping. Bug reports, ideas, new looks and code are all welcome.

## Reporting a problem

Open an issue and fill in the form. The most useful facts are the widget version, your distribution, the player, the song
(for lyrics problems) and the log lines the form asks for. `bash /usr/share/lyric-widget/doctor.sh` prints the system facts.

## Building and testing

See "For developers" in the [README](README.md). In short:

```
./build.sh                                  # whole widget, installed into /usr (asks for sudo)
node tests/settings.test.js                 # also layouts.test.js and presets.test.js
cmake -B build -S . -G Ninja -DBUILD_TESTS=ON && cmake --build build && ctest --test-dir build
```

## Where things are

- **A setting:** define it once in `plasmoid/contents/ui/settings/model.js`, add the key to `plasmoid/contents/config/main.xml`,
  then run `node tools/gen-settings.js`. Labels have no unit in them (the unit goes in `unit.suffix`), places are X and Y,
  sizes are Width and Height. The settings test enforces this.
- **A look:** add it to `plasmoid/contents/ui/viz/presets.js`, run `tools/gallery/render.sh` to draw its picture, and commit the
  new pictures it writes.
- **A lyric provider or a matching rule:** `src/LyricsFetcher.cpp` and `src/Text.h`, with a case in `tests/matching.cpp`. A
  report that one song has no lyrics is usually a gap in a rule, so fix the rule and add the song as a test case.
- **Your own styles:** `examples/` and [docs/custom-styles.md](docs/custom-styles.md).

## Pull requests

Keep a change to one subject, run the tests above, and say how you looked at it if it changes what the widget draws. The
template asks for exactly that. By contributing you agree your work is licensed under GPL-3.0, like the rest of the project.
