# Architecture

This file is the project's long-term memory. Read it before changing code,
and update it when you add or move a system. The vision's rule is **build
systems once, feed them data forever**: a new enemy, quest, item or region
should mostly be data, not a new engine.

## Layers

```
            game_data/*.json   assets/tiles/*.tmx   assets/images/sprites/*.json
                      │                │                      │
                      ▼                ▼                      ▼
  lib/content/   GameData: typed, validated definitions (no game state)
                      │
  lib/rules/     pure Dart rules: stats, damage math, items, loot,
                 inventory, quest log, hero profile (no Flutter, no Flame)
                      │
  lib/game/      Flame simulation + rendering: world, entities, combat,
                 AI, systems, FX. Talks to the UI only through:
                   GameSession  (ValueNotifiers, game → UI)
                   GameCommands (interface, UI → game)
                   InputState   (filled by widgets, read by the hero)
                      │
  lib/client/    Flutter: screens, HUD, panels, touch controls, theme
  lib/services/  persistence (SaveRepository)
```

Dependency rules:

- `content` imports nothing from the other layers.
- `rules` imports only `content`. Keep it free of Flutter and Flame so it can
  run in tests, tools and (later) on a server.
- `game` imports `content` and `rules`. It never imports `client`.
- `client` reads `game` only through `GameSession`, calls it only through
  `GameCommands` and `InputState`, and may use `content` and `rules` for
  display.

## Coordinates

- **World space** is in tiles: `ground` (a `Vector2`) is where an actor's feet
  are. All simulation (movement, collision, ranges, AI) happens here.
- **Screen space** is the isometric projection of world space, done by
  `Iso` (`lib/game/world/iso.dart`) with 128×64 tiles:
  `screen = ((x − y)·64 + H·64, (x + y)·32)` where `H` is the map height.
- `z` is height above the ground in screen pixels (jumps, arcs, flying
  arrows).
- **Depth** is `ground.x + ground.y`: `EntityLayer` sorts every entity and tall
  prop by it each frame, so things further "south" draw on top. Tall props
  fade when they would hide the hero.

## The game (`lib/game/`)

`DungeonRealmsGame` (`dungeon_realms_game.dart`) owns the world and every
system, and implements `GameCommands`. Systems get the game through a
reference and talk to each other through it (`game.combat`, `game.quests`...).

### System registry

Search here before creating anything. If a system exists, extend it.

| System | Where | Job |
| --- | --- | --- |
| Content | `content/game_data.dart` | Loads and validates `game_data/*.json` and sprite metadata |
| Region map | `game/world/region_map.dart` | Parses the Tiled map: terrain corners, props, interactives, gameplay objects |
| Collision | `game/world/collision_world.dart` | Circles, boxes and segments in a spatial hash, plus blocked terrain; tagged shapes (boss gates) can be switched on and off |
| Navigation | `game/world/nav_grid.dart` | Walkability grid and Dijkstra flow fields toward the hero, so chasers path around obstacles |
| Render layers | `game/world/layers.dart` | `GroundLayer` (decals, telegraphs), `EntityLayer` (depth sort, culling, occlusion fade), `OverlayLayer` (floating text, particles) |
| Input | `game/input.dart` | `InputState`: move vector, aim, held attack, buffered ability presses |
| UI bridge | `game/session.dart` | `GameSession` notifiers and the `GameCommands` interface |
| Hero | `game/entities/hero.dart` | Movement, skills, ultimate meter, potion, gathering, portrait mood |
| Enemies | `game/entities/enemy.dart`, `game/ai/enemy_brain.dart` | Stats with level scaling; idle → chase → return AI, aggro, leash, phases |
| Interactables | `game/entities/interactables.dart`, `npc.dart` | Resource nodes, chests, waypoints, boss gates, NPCs |
| Ability runner | `game/combat/ability_runner.dart` | Turns an `AbilityDef` into a cast, then runs its behavior |
| Combat | `game/combat/combat_system.dart` | The one place damage and healing happen: crits, armor, statuses, knockback, feedback, deaths |
| Projectiles / areas | `game/combat/projectile.dart`, `area_effect.dart` | Moving hitboxes and ground effects (vines, slams, storms, hot sauce) |
| Statuses | `game/combat/status_effects.dart` | Root, slow, stun, burn |
| Telegraphs | `game/combat/telegraph.dart` | Ground warnings for enemy wind-ups |
| Legendary powers | `game/combat/powers.dart` | Build-changing hooks keyed by power id |
| Spawns | `game/systems/spawn_system.dart` | Packs in spawn zones, respawn timers, elite packs |
| Public events | `game/systems/public_event_system.dart` | Timed wave events with a defend target |
| Bosses | `game/systems/boss_system.dart` | Arena engage, gates, boss HUD, reset on wipe, victory |
| Quests & NPCs | `game/systems/quest_director.dart` | NPC dialog, quest offer / accept / turn-in, services |
| Items | `rules/items.dart` | `ItemFactory`: rolls rarities, bases, affixes, legendaries |
| Loot | `rules/loot.dart` | `LootRoller`: loot tables into drops |
| Inventory | `rules/inventory.dart` | Bag, equipment, materials, gold, Shiny Bits |
| Stats | `rules/stats.dart` | `HeroStats.compute`, `DamageMath` |
| Quest log | `rules/quest_log.dart` | Quest states and objective progress |
| Hero profile | `rules/hero_profile.dart` | Everything saved about a hero |
| Saves | `services/save_repository.dart` | `LocalSaveRepository` (shared_preferences), `MemorySaveRepository` (tests) |
| FX | `game/fx/fx.dart`, `ambient.dart` | Particles, floating text, screen shake, region ambience, prop emitters (campfires) |
| Sprites | `game/render/character_sprite.dart` | Sprite sheets and the animator |

### Frame order

`DungeonRealmsGame.update` clamps `dt` to 1/20 s, then runs:

1. scheduled callbacks (`after`)
2. components (hero input and movement, enemy AI, casts, projectiles, areas,
   loot, particles)
3. spawns, public events and bosses
4. the hero flow field (rebuilt when the hero changes cell)
5. camera, occlusion fade and area banners
6. a HUD sync every 0.1 s (`GameSession` notifiers), and an autosave every
   20 s or when something important happens (`saveSoon`)

### Combat pipeline

```
InputState (key / button / touch)
  → HeroEntity._tryAbility       unlock, cooldown, ultimate meter, input buffer
  → AbilityRunner.begin          cooldown, animation, enemy telegraph, AbilityCast
  → AbilityCast.update           wind-up, then release
  → AbilityRunner._execute       behavior: projectile, area, dash, charge...
  → Projectile / AreaEffect      hit tests in world space
  → CombatSystem.hit             armor, crit, statuses, knockback, flash, numbers
  → death → onEnemyKilled        xp, loot, quests, boss / event hooks
```

Enemies use the same pipeline; `EnemyBrain` picks the ability instead of
input. Details: [docs/systems/combat.md](docs/systems/combat.md).

### Entities

```
GameEntity (entity.dart)            ground, z, depth, despawn
├─ Actor (actor.dart)               hp, stats, statuses, casts, dash, animator
│  ├─ HeroEntity
│  ├─ EnemyEntity                   + EnemyBrain
│  └─ EventTargetEntity             Pip's wagon
├─ PropBackedEntity                 a Tiled prop that does something
│  ├─ ResourceNodeEntity            ore veins, herbs
│  └─ ChestEntity, WaypointEntity, BossGateEntity
├─ NpcEntity
├─ LootDrop                         gold, items, materials, health orbs
└─ Projectile, AreaEffect
```

## The client (`lib/client/`)

- `app.dart` loads `GameData`, then routes Title → Hero Select → Game.
- `game_screen.dart` hosts the `GameWidget`, owns keyboard focus and mouse
  input, and stacks the `Hud` and `PanelHost` on top. Flame's `GameWidget`
  gets a focus node that can never take focus, because otherwise it swallows
  every key.
- `hud/` draws the reactive portrait, bars, skill bar or touch cluster,
  joystick, quest tracker, boss and event bars, banners and toasts. It only
  listens to `GameSession`.
- `panels/` holds the inventory, quest log, dialog, waypoint picker,
  pause and difficulty, and death screens. `PanelHost` pauses the game while a
  modal panel is open.
- `theme.dart` holds the palette and buttons from the vision page.

## Persistence

`HeroProfile` holds everything saved about a hero: level, XP, inventory,
quests, waypoints, Day Jobs, difficulty, boss kills and statistics.
`SaveRepository` stores profiles as JSON; `LocalSaveRepository` uses
shared_preferences with keys `dr.heroes`, `dr.hero.<id>` and `dr.settings`.
Profiles carry a `version` for migrations.

Phase 04 adds a `SupabaseSaveRepository` behind the same interface. Nothing
else needs to change.

## Multiplayer readiness (phase 05)

Combat will become server-authoritative (Colyseus). To keep that move
cheap:

- Simulation runs in world space with plain numbers. Rendering, FX and HUD
  are separate.
- All tuning lives in `game_data/`. The server can load the same JSON.
- Damage, crits, loot and items go through one place each
  (`CombatSystem.hit`, `LootRoller`, `ItemFactory`), so they can move to the
  server as units.

## Content and assets

- `game_data/*.json`: every definition. Schema and examples are in
  [docs/systems/content.md](docs/systems/content.md) and the linked system
  docs. `GameData.validate()` cross-checks every reference and runs in the
  tests.
- `assets/tiles/goblinwood.tmx`: the region map, made by
  `tool/maps/generate_goblinwood.dart`. It can also be edited in Tiled. See
  [docs/systems/maps.md](docs/systems/maps.md).
- `assets/images/sprites/<id>.png` + `.json`: character sheets and animation
  metadata, made by `tool/art/`. See
  [docs/systems/art.md](docs/systems/art.md).

## Where to add things

| I want to add... | Do this |
| --- | --- |
| An enemy | Entry in `enemies.json` (+ a pack). New look → sprite in `tool/art/characters.dart` |
| An enemy or hero ability | Entry in `abilities.json` using an existing behavior. Only add a behavior to `AbilityRunner` if no parameters can express it |
| An item base, affix or legendary | `items.json`. A legendary power that changes a skill also needs a hook (`powers.dart`) |
| A loot source | `loot_tables.json`, referenced by an enemy, chest, event or boss |
| A quest | `quests.json` (+ the NPC in `npcs.json`). Objective types: kill, collect, event, discover, open, talk |
| A public event | `world.json` `events` + an `event` zone in the map |
| A resource node or Day Job | `world.json` `resources` / `dayJobs` + a `resource` object in the map |
| A region | A Tiled map + `world.json` region + its content |
| A hero | `heroes.json` + abilities + sprite rig + concept sheet; the combat framework stays the same |
| A HUD element | A widget in `lib/client/hud/` listening to a new `GameSession` notifier |

Then add a test (see [CODING_RULES.md](CODING_RULES.md)).
