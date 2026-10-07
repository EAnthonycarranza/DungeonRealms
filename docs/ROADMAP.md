# Roadmap

From the vision: **prove fun before scale.** The first goal is a Ranger,
Goblinwood, goblins and combat that feels good.

## Status

| Phase | Scope | Status |
| --- | --- | --- |
| 01 Movement | Flutter shell, Flame world, Ranger, joystick, camera, collision | ✅ Done |
| 02 Combat | Basic attack, dodge, abilities, enemy AI, damage, death | ✅ Done |
| 03 Goblinwood | Tiled map, quests, loot, mining, waypoints, event, Grizzlefang | ✅ Done (vertical slice) |
| 04 Persistence | Supabase auth, hero saves, inventory, quest progress, gear | ⏭ Next |
| 05 Multiplayer | 2 players → 4-player dungeon → shared zones → bosses → raids | Later |

## What phases 01–03 delivered

- **Shell**: title, hero select (8 heroes, Ranger playable with 2 looks),
  local saves with several heroes, pause menu, world difficulty.
- **Movement**: keyboard and mouse, or a floating joystick on touch; camera
  follow with zoom by screen size; collision against terrain, props and walls;
  flow-field pathing for enemies.
- **Combat**: Quick Shot (hold), Precision Shot, Multi-Shot (level 2), Vine
  Trap (level 3), the Arrow Storm ultimate (level 4) and a Backflip dodge.
  Tap to auto-aim, drag to aim on touch, mouse aim on desktop. Input is
  buffered and skills cut basic attacks short. Telegraphed enemy attacks,
  root, slow, stun and burn, knockback, crits, damage numbers, hit flash,
  screen shake, a reactive portrait, death and respawn.
- **Enemies**: melee, ranged, caster and phased AI; packs; leashing;
  waypoints as sanctuaries. The elite Warboss Snagtooth and the three-phase
  Grizzlefang (charge into walls for a break window, roar adds, honey rage) in
  a sealed arena.
- **Goblinwood**: a 76×76 isometric map with Buckleburg, roads, a goblin
  camp, a stream and bridge, a hidden hollow and the boss arena; 4 waypoints;
  12 spawn zones; area banners; discoverable spots.
- **Quests**: 7 quests from 4 NPCs (kill, collect, event, discover, open,
  talk), dialog with turn-in chains, quest log and tracker.
- **Loot**: 5 rarities, 6 slots, 12 affixes, 6 legendaries with powers that
  change skills, materials, health orbs, chests; an inventory with equipping,
  upgrade arrows, selling (Pip) and salvaging (Hilda).
- **Day Jobs**: Mining and Herbalism with levels; enemies interrupt
  gathering.
- **Event**: Wagon Wheel Wipeout, four waves against Pip's wagon.
- **Difficulty**: Normal to *Why Would You Do This?*, each unlocked by beating
  Grizzlefang on the tier before. Spicy adds hot-sauce puddles, Very Spicy
  adds elite packs.

## Known gaps in the slice

- No sound or music yet.
- Gold and Shiny Bits pile up with nothing to spend them on: Blacksmithing,
  Alchemy and shops aren't built.
- No talents and no Hero Rank (both post-slice by design).
- The *Angry Trees* difficulty mechanic is a placeholder.
- No instanced dungeon yet; Grizzlefang's cave is scenery.
- The other seven heroes are menu entries only.

## Suggested next tasks

Small, testable steps, roughly in order:

1. **Audio**: hit, shot, UI and boss cues, plus Goblinwood ambience, with a
   volume setting.
2. **Blacksmithing and Alchemy**: upgrade or reroll gear with ore and Shiny
   Bits; brew potions from Sniffleleaf. This gives the currencies a use.
3. **A Goblinwood cave dungeon**: an 8–15 minute instance behind the hidden
   hollow, reusing spawns, bosses and loot tables.
4. **A second hero** (Barbarian or Sorceress) to prove that new heroes reuse
   the combat framework.
5. **Phase 04**, below.

## Phase 04: Persistence (Supabase)

- Add `SupabaseSaveRepository` implementing `SaveRepository`; keep
  `LocalSaveRepository` for offline play.
- Auth: start anonymous, upgrade to email or OAuth; import local heroes on
  first sign-in.
- Table `heroes(id, owner, class, look, level, profile jsonb, version,
  updated_at)` with row-level security limited to the owner. The `profile`
  column holds `HeroProfile.toJson()`.
- Conflict policy: newest `updated_at` wins, guarded by `version`.
- Later, inventory and currency writes move behind server validation (they
  must before trading and the auction house).

## Phase 05: Multiplayer (Colyseus)

- An authoritative room per region shard. The server loads the same
  `game_data/*.json` and runs combat; clients send inputs and render state.
- Port the pure rules (`lib/rules`) and the ability runner's behaviors first;
  they are the parts the server must own.
- Order: 2 players in Goblinwood → a 4-player dungeon → shared zones with
  about 20–30 players → public bosses (Big Problems) → raids.
