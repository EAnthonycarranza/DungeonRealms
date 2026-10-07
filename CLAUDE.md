# Notes for AI coding agents

Dungeon Realms is a Flutter + Flame isometric action RPG for **iOS and
Android**. The architecture is the project's permanent memory: don't reinvent
it, extend it.

## Read first

1. [ARCHITECTURE.md](ARCHITECTURE.md): layers, the system registry, where to
   add things.
2. [CODING_RULES.md](CODING_RULES.md): the rules every change follows.
3. The doc for the system you're touching, in [docs/systems/](docs/systems/).
4. [docs/ROADMAP.md](docs/ROADMAP.md) for what's done and what's next, and
   [docs/VISION.md](docs/VISION.md) for the game itself.

## Commands

```bash
export PATH="/opt/flutter/bin:$PATH"          # if flutter isn't on PATH
flutter pub get
dart format lib test tool                     # 160 columns (analysis_options.yaml)
flutter analyze                               # must report no issues
flutter test                                  # must pass
flutter run                                   # on a connected phone or emulator
flutter build apk --release                   # Android (needs the Android SDK)
flutter build ios --release --no-codesign     # iOS (macOS + Xcode only; CI does this)
flutter run -d chrome                         # quick checks in a browser
dart run tool/maps/generate_goblinwood.dart   # regenerate the map
ART=props flutter test tool/art/generate_art_test.dart   # regenerate art (groups: terrain, decor, props, sprites, icons, appicon, mappreview)
```

Fast manual checks: `--dart-define=QUICKSTART=true`, and in debug and profile
builds `--dart-define=START_AT=<waypoint id> --dart-define=START_LEVEL=<n>`
(on web: `?quickstart`, `?at=snagtooth_camp&level=6`).

## Rules that matter most

- **Search before creating.** Check the system registry and grep before
  adding a class. One of each system.
- **Content is data.** New enemies, abilities, items, quests and events go in
  `game_data/*.json` with a check in `GameData.validate()`. Code knows
  behaviors, not specific content.
- **Small tested tasks.** Add or update a test with every change. Integration
  tests use `testWithGame` and drive frames with `game.update(1 / 30)`.
- **Docs travel with code.** Update ARCHITECTURE.md or the system doc in the
  same commit as the change.
- **Layers.** `content` and `rules` stay free of Flutter and Flame; `game`
  never imports `client`; the UI talks to the game through `GameSession`,
  `GameCommands` and `InputState`.
- **World space.** Simulate in tiles (`ground`), render through `Iso`.
- **Phones first.** Test at phone size in landscape, keep UI in `SafeArea`,
  handle the Android back button, and never use web-only APIs.
- **Generated assets.** Don't hand-edit generated PNGs, sprite JSON or the
  map; change `tool/art` or `tool/maps` and rerun.
