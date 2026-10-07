# Coding Rules

These rules keep Dungeon Realms coherent across many coding sessions and
contributors, human or AI. They come from the vision's vibe-coding rules.

## The four rules

1. **Search before creating.** Before adding a manager, system, controller,
   helper or widget, look for the existing one: check the system registry in
   [ARCHITECTURE.md](ARCHITECTURE.md), then grep (`grep -rn "class .*Quest" lib`).
   Extend what exists. Never add a second `InventoryManager`, `QuestController`
   or `EnemySystem`.
2. **Docs are memory.** ARCHITECTURE.md, this file and `docs/systems/*.md`
   travel with the code. A change to a system, a JSON schema or a convention
   updates its doc in the same commit.
3. **Data-driven content.** The 100th enemy is a definition, not a new engine.
   Numbers, names, text and tuning live in `game_data/`. Code only knows
   *behaviors* (ability behaviors, status types, objective types, power
   hooks, difficulty mechanics), never specific monsters, items or quests.
4. **Small tested tasks.** One feature, one enemy, one boss phase, one quest
   handler at a time. Test it, review the diff, commit, then continue.

## Before every commit

```bash
dart format lib test tool   # 160 columns, set in analysis_options.yaml
flutter analyze             # must say "No issues found!"
flutter test                # must pass
```

For anything that changes how the game plays or looks, also run it
(`flutter run -d chrome`, or `?quickstart` / `?at=<waypoint>` for a fast start)
and check both a desktop window and a phone-sized landscape window (for
example 844×390).

## Layers

- `lib/content` and `lib/rules` never import Flutter widgets or Flame.
- `lib/game` never imports `lib/client`.
- The UI reads game state only from `GameSession` and changes it only through
  `GameCommands` or `InputState`. Don't reach into entities from widgets.
- Persistence goes through `SaveRepository`; nothing else touches storage.

## Content (`game_data/`)

- Ids are `snake_case` and stable: saves refer to them. Rename an id only
  with a save migration.
- Every new reference (an ability on an enemy, an item in a loot table, a pack
  in an event...) gets a check in `GameData.validate()`. The content test
  fails on any problem.
- Every field in the JSON is read by code, except comments (`$schema_doc`
  and `note`). Don't add "for later" fields; remove fields that nothing
  reads.
- Humor goes in names, barks, quest text and flavor. Ability descriptions and
  tooltips state exactly what happens.
- New fields are documented in the matching `docs/systems/*.md`.

## Game code (`lib/game`)

- Simulate in **world space** (tiles, `ground`), render in screen space. Never
  use screen pixels for ranges, speeds or collision.
- Everything time-based uses `dt` seconds. For delays use `game.after(...)`,
  not `Future.delayed`.
- All damage and healing go through `CombatSystem` (`hit`, `heal`). All loot
  goes through `LootRoller`, all items through `ItemFactory`.
- Use a new ability behavior only when no combination of existing parameters
  can express the idea. Same for statuses and objective types.
- Keep hot paths (entity update and render, collision, AI) light: reuse
  `Vector2` scratch objects and cached `Paint`s instead of allocating every
  frame.
- Randomness that affects outcomes takes an injectable `math.Random`
  (`ItemFactory`, `LootRoller`) so tests can seed it.
- Enemy attacks are readable: wind-ups with telegraphs, no instant
  unavoidable damage from bosses.

## UI code (`lib/client`)

- Phones first: iOS and Android are the targets. Aim for touch targets of
  44 px or more, make every screen fit a short landscape phone (844×390) with
  no essential button below the fold, keep content inside `SafeArea`, and
  give every new screen an Android back behavior.
- Don't use web-only APIs (`dart:html`, `package:web`) or anything that
  assumes a mouse or keyboard.
- Every keyboard shortcut has a touch equivalent and is listed in the pause
  menu's controls table.
- Colors, fonts and buttons come from `theme.dart` (`DR` palette,
  `GoldButton`, `GhostButton`).

## Dart style

- Follow `analysis_options.yaml` (strict casts, no dynamic calls, final
  locals, single quotes).
- Doc comments (`///`) on public classes and on anything non-obvious. Comments
  explain *why*, not what.
- Prefer small classes with one job. If a file passes about 600 lines, look
  for a second job inside it.
- Name things after game concepts (`SpawnZone`, `BossArena`, `QuestLog`), not
  patterns (`Manager`, `Helper`).

## Tests (`test/`)

- `test/content/`: data loads and `validate()` reports no problems.
- `test/rules/`: pure rules (stats, items, loot, inventory, quests, saves).
- `test/game/`: headless integration tests with `testWithGame`. They boot
  the real map and content, set up a situation, run frames with
  `game.update(1 / 30)` and check the outcome.
- A bug fix comes with a test that fails without the fix.

## Assets

- Tiles, props, sprites and icons are generated by `tool/art`. Don't hand-edit
  generated PNGs or sprite JSON; change the generator and rerun it.
- `assets/tiles/goblinwood.tmx` is generated by
  `tool/maps/generate_goblinwood.dart`. If you edit it in Tiled instead, stop
  regenerating it (or port the change into the generator), or the next run
  will overwrite your edit.
- Hand-made art (the hero concept sheets) lives in `assets/images/heroes/`.

## Commits

- Imperative subject line under ~70 characters ("Add Soggyroot mushroom
  packs"), then a short body explaining why.
- One topic per commit. Content, code and docs for the same feature belong
  together.
