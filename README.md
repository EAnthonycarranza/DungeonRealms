# Dungeon Realms

A colorful 2.5D isometric, real-time action RPG with cartoon fantasy humor,
for **iOS and Android**. One Dart codebase (Flutter for the app, Flame for the
game) builds both native apps. Heroes roam regions, smash monster packs, chase
ridiculous loot, learn Day Jobs and, eventually, enter challenges the game
itself admits are a terrible idea.

This repository holds the first playable slice from the
[Game Vision](docs/VISION.md): **a Ranger, Goblinwood, goblins and combat
that feels good** (roadmap phases 01–03).

## What's in the slice

- **The Ranger**, with two looks (Leafwarden, Wildheart): Quick Shot, Precision
  Shot, Multi-Shot, Vine Trap, the Arrow Storm ultimate and a Backflip dodge.
  The HUD portrait reacts to what's happening (attacking, stunned, panicking,
  ulting).
- **Goblinwood (levels 1–8)**: Buckleburg Gate, the Wagon Crossroads,
  Snagtooth's goblin camp, a suspicious hollow, and Grizzlefang's Hollow.
- **Combat**: free movement, aimed and auto-aimed skills, telegraphed enemy
  attacks, crowd control, damage numbers, death and respawn.
- **Enemies**: Goblin Grunts, Slingers and Shamans, the elite Warboss
  Snagtooth, and **Grizzlefang, The Unbearable**: a three-phase boss with
  charges, roars and a honey rage, fought in a sealed arena.
- **Loot**: five rarities, random affixes, and six legendaries whose powers
  change how skills work.
- **Seven quests** from four NPCs, **Mining** and **Herbalism**, **waypoints**,
  and the **Wagon Wheel Wipeout** public event.
- **World difficulty** from Normal to *Why Would You Do This?*, unlocked by
  beating Grizzlefang on the previous tier.
- **Built for phones**: landscape, full screen, a floating joystick and a
  thumb cluster with tap-to-auto-aim and drag-to-aim. The HUD keeps clear of
  notches and the home indicator, the Android back button opens the pause
  menu, and leaving the app pauses the game and saves. Saves stay on the
  device. (Keyboard and mouse also work, for development.)

The other seven heroes and five regions appear in the menus as "coming soon".
Persistence (Supabase) and multiplayer (Colyseus) come in later phases; see
the [roadmap](docs/ROADMAP.md).

## Running it on a phone

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(developed on Flutter 3.47 / Dart 3.13) and then `flutter pub get`.

**Android** (from Windows, macOS or Linux): install Android Studio or the
Android command-line tools, turn on USB debugging on the phone, plug it in,
and run:

```bash
flutter devices          # the phone should be listed
flutter run --release    # build, install and launch
```

No Flutter setup? Every push builds an installable APK: open the latest
**Mobile builds** run under the repository's *Actions* tab and download the
`dungeon-realms-android` artifact.

**iOS** (needs a Mac with Xcode): open `ios/Runner.xcworkspace` in Xcode once,
choose your team under *Signing & Capabilities* for the Runner target, then
plug in the iPhone and run `flutter run --release`. The iOS Simulator works
with plain `flutter run`.

**Quick checks without a phone:** `flutter run -d chrome` runs the same game in
a browser. It's handy for development; the phones are the real targets.

### Controls

| Action | Keyboard & mouse | Touch |
| --- | --- | --- |
| Move | WASD / arrow keys | Left-thumb joystick |
| Quick Shot | Hold left mouse (or J) | Hold the big button |
| Skills | Q, E, R and the ultimate on F (aim with the mouse); right mouse = Q | Tap to auto-aim, drag to aim |
| Backflip (dodge) | Space | Dodge button |
| Potion | H | Potion button |
| Talk / Mine / Open / Travel | G or Enter | Interact button |
| Inventory / Quests / Menu | I (or Tab, B) / L / Esc | Top-right buttons |

### Developer shortcuts

- `--dart-define=QUICKSTART=true` (or `?quickstart` on web) skips the menus
  and starts a fresh Ranger.
- In debug and profile builds, `--dart-define=START_AT=<waypoint id>` and
  `--dart-define=START_LEVEL=<n>` start there at that level, for example
  `flutter run --dart-define=START_AT=grizzlefang_hollow --dart-define=START_LEVEL=8`.
  On web: `?at=grizzlefang_hollow&level=8`. Waypoint ids are in
  `game_data/world.json`.

## Releasing

**Google Play.** Create an upload keystore once and keep it safe (losing it
means losing the ability to update the app):

```bash
keytool -genkey -v -keystore ~/dungeon-realms-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/dungeon-realms-upload.jks
```

`flutter build appbundle --release` then writes a signed
`build/app/outputs/bundle/release/app-release.aab` to upload in the Play
Console. Without `key.properties`, release builds are signed with the debug
key: fine for sideloading, rejected by Play.

**App Store.** On a Mac with your team set in Xcode, `flutter build ipa
--release` produces an archive to upload with Xcode or Transporter
(TestFlight first). The app declares no non-exempt encryption, so uploads
skip the export-compliance question.

**Identity.** The Android application id is `com.dungeonrealms.dungeon_realms`
and the iOS bundle id is `com.dungeonrealms.dungeonRealms`. Change them in
`android/app/build.gradle.kts` and in Xcode before the first store upload if
you want different ones; they can't change afterwards. The version comes from
`version:` in `pubspec.yaml` (`0.3.0+1` = version 0.3.0, build 1).

## Continuous integration

`.github/workflows/mobile.yml` runs on every push and pull request:

1. formatting, `flutter analyze` and `flutter test`;
2. Android release APK and App Bundle (uploaded as artifacts);
3. an iOS release build without code signing, on macOS.

## Project layout

```
lib/
  main.dart        entry point (dev shortcuts, orientation)
  client/          Flutter: screens, HUD, panels, theme (the "client/" layer)
  game/            Flame: world, entities, combat, AI, systems, FX (the "game/" layer)
  content/         typed models + loader + validation for game_data/*.json
  rules/           pure Dart game rules: stats, items, loot, inventory, quests, saves
  services/        persistence (local today, Supabase later)
android/, ios/     native app projects (icons, launch screens, signing, orientation)
web/               browser build for quick development checks
game_data/         all content as JSON: heroes, abilities, enemies, items, quests...
assets/
  tiles/           Tiled map (goblinwood.tmx), tilesets, prop images
  images/          concept art, sprite sheets (+ animation JSON), icons
  fonts/           Lilita One + Nunito (OFL)
tool/
  art/             procedural art generator (tiles, props, sprites, icons)
  maps/            Goblinwood map generator
test/              content validation, rules, and headless game tests
docs/              vision, roadmap and one doc per system
```

## Tests and checks

```bash
flutter analyze   # must report no issues
flutter test      # content validation, rules, and headless integration tests
```

The integration tests in `test/game/` boot the real game (real map, art and
content) without a screen and drive it frame by frame: walking into walls,
killing goblins, casting every skill, quests, mining, the event, the boss
fight and the arena seal. `test/client/` checks the phone behaviors: leaving
the app pauses and saves, and the Android back button toggles the pause menu.

## Regenerating art and the map

Every image and the map are generated by code, so they can be changed and
rebuilt like any other source file:

```bash
ART=terrain,decor,props,icons flutter test tool/art/generate_art_test.dart
ART=sprites SPRITES=ranger_leafwarden flutter test tool/art/generate_art_test.dart
ART=appicon flutter test tool/art/generate_art_test.dart   # launcher icons + launch logo
dart run tool/maps/generate_goblinwood.dart
```

See [docs/systems/art.md](docs/systems/art.md) and
[docs/systems/maps.md](docs/systems/maps.md). The hero concept-art sheets in
`assets/images/heroes/` are hand-made art from the vision document.

## Documentation

Start with [ARCHITECTURE.md](ARCHITECTURE.md) and
[CODING_RULES.md](CODING_RULES.md). AI coding agents should also read
[CLAUDE.md](CLAUDE.md). Each system has its own page in
[docs/systems/](docs/systems/).

## Credits

Fonts: [Lilita One](https://fonts.google.com/specimen/Lilita+One) and
[Nunito](https://fonts.google.com/specimen/Nunito), both under the SIL Open
Font License (see `assets/fonts/`).
