# Content (`game_data/`)

All game content is JSON in `game_data/`. `GameData.load()`
(`lib/content/game_data.dart`) reads every file into typed definitions, and
`GameData.validate()` cross-checks every reference. The content test fails
on any problem, so a typo in an id never reaches the game.

| File | Holds | Doc |
| --- | --- | --- |
| `heroes.json` | Heroes, looks, stats, ability slots, starting gear | [below](#heroes) |
| `abilities.json` | Every hero and enemy ability | [combat.md](combat.md) |
| `enemies.json` | Level scaling, enemies, packs | [below](#enemies) |
| `items.json` | Rarities, slots, stats, affixes, bases, legendaries, materials | [loot.md](loot.md) |
| `loot_tables.json` | What drops from enemies, chests, events, bosses | [loot.md](loot.md#loot-tables) |
| `quests.json` | Quests, objectives, rewards, dialog | [quests.md](quests.md) |
| `npcs.json` | NPCs, barks, services | [quests.md](quests.md#npcs) |
| `world.json` | Terrain, regions, resources, Day Jobs, events, potion, health orbs | [below](#world) |
| `progression.json` | XP curve, ultimate meter, combat constants, difficulties | [progression.md](progression.md) |

Conventions:

- Ids are `snake_case` and stable; saves store them.
- `$schema_doc` points to the doc for the file, and `note` fields are
  comments. Every other field is read by code.
- Distances are in world tiles, times in seconds, chances in 0–1, damage as
  a multiplier of the attacker's attack stat.
- Ranges are `[min, max]` arrays.

Content loads at start-up. After editing JSON, restart the app (hot reload
doesn't reload assets); `flutter test test/content` checks your edit.

## Heroes

```jsonc
{
  "id": "ranger",
  "name": "Ranger",
  "kicker": "RANGED • TRAPS",            // hero select label
  "role": "Wildshot Archer",
  "description": "Mobile ranged damage with...",
  "tone": "green",                        // accent color (DR.tone)
  "playable": true,                       // false = shown as "coming soon"
  "skills": ["Precision Shot", "Multi-Shot", "Vine Trap", "Arrow Storm"],
  "baseStats": { "maxHp": 120, "attack": 12, "armor": 10, "critChance": 0.08,
                 "critDamage": 0.6, "attackSpeed": 1.0, "moveSpeed": 4.4, "hpRegen": 1.5 },
  "growth": { "maxHp": 14, "attack": 2.4, "armor": 2 },   // added per level
  "basicAbility": "ranger_quick_shot",
  "dodgeAbility": "ranger_backflip",
  "abilities": [                           // slots Q, E, R, then the ultimate (F)
    { "id": "ranger_precision_shot", "unlockLevel": 1 },
    { "id": "ranger_multi_shot", "unlockLevel": 2 },
    { "id": "ranger_vine_trap", "unlockLevel": 3 },
    { "id": "ranger_arrow_storm", "unlockLevel": 4, "ultimate": true }
  ],
  "startingGear": [{ "base": "short_bow", "rarity": "common" }],  // or { "unique": "<legendary id>" }
  "looks": [{
    "id": "leafwarden",
    "name": "Leafwarden",
    "sprite": "ranger_leafwarden",              // assets/images/sprites/<sprite>.json
    "sheet": "heroes/ranger_leafwarden.webp",   // concept art sheet under assets/images/
    "expressions": { "idle": [178, 105, 78], "stunned": [...], "attack": [...],
                     "ultimate": [...], "panic": [...] }   // face crops: centre x, y, radius
  }]
}
```

Stats are computed by `HeroStats.compute` (`lib/rules/stats.dart`): base +
growth × (level − 1) + gear. `attackSpeed` and `moveSpeed` from gear
multiply the base value. Caps: crit chance 75%, cooldown reduction 40%, bonus
move speed 50%.

A playable hero must have its abilities defined, a sprite for each look with
the animations its abilities use, and all five expressions. Non-playable
heroes need only a look with a concept sheet.

## Enemies

```jsonc
"scaling": { "hpPerLevel": 0.32, "attackPerLevel": 0.22, "armorPerLevel": 3, "xpPerLevel": 0.25 },
"enemies": [{
  "id": "goblin_grunt",
  "name": "Goblin Grunt",
  "title": null,                     // subtitle for elites and bosses
  "tags": ["goblin"],                // quests can count kills by tag
  "rank": "normal",                  // normal | elite | boss
  "sprite": "goblin_grunt",
  "tint": null,                      // optional color tint, "#rrggbb"
  "stats": { "hp": 42, "attack": 7, "armor": 6, "speed": 3.2, "radius": 0.34 },
  "xp": 14,
  "ai": "melee",                     // melee | ranged | caster | phased
  "aggroRange": 7.5,
  "leashRange": 16,                  // gives up and walks home beyond this
  "preferredRange": 0,               // ranged and caster AI keep this distance
  "abilities": ["goblin_club_smack"],
  "phases": [],                      // phased AI only, see below
  "loot": "goblin_common",           // loot table id
  "barks": ["I bonk you now."],
  "deathBark": null
}],
"packs": [{ "id": "goblin_raiders",
            "members": [{ "enemy": "goblin_grunt", "count": 1 }, { "enemy": "goblin_slinger", "count": 2 }] }]
```

Level scaling (an enemy's level comes from its spawn zone or event):

- HP and attack: `base × (1 + perLevel × (level − 1))`
- Armor: `base + armorPerLevel × (level − 1)`
- XP: `base × (1 + xpPerLevel × (level − 1))`, then the difficulty multiplier

Phased enemies (elites and bosses) switch ability lists as their health
drops. When a phase starts, its `onEnter` ability is cast once (summons,
roars, rages), and a boss shows a "PHASE n" banner with the phase's
`subtitle`:

```json
"phases": [
  { "from": 1.0, "abilities": ["grizzlefang_maul", "grizzlefang_charge"] },
  { "from": 0.6, "onEnter": "grizzlefang_roar", "subtitle": "He called for snacks. The snacks have clubs.",
    "abilities": ["grizzlefang_maul", "grizzlefang_charge", "grizzlefang_slam"] },
  { "from": 0.3, "onEnter": "grizzlefang_honey_rage", "subtitle": "He found the honey. THIS SEEMS BAD.", "abilities": ["..."] }
]
```

AI types (`lib/game/ai/enemy_brain.dart`):

- `melee` walks up and uses melee abilities.
- `ranged` keeps `preferredRange`, needs line of sight and leads moving
  targets.
- `caster` is like ranged and also heals allies (`heal_allies`).
- `phased` is melee plus the phase rules above.

All of them wander near home when idle, aggro inside `aggroRange` (never on a
hero standing at a waypoint; see [combat.md](combat.md#enemy-ai)), call
nearby pack mates when hit, and leash home.

Packs are placed by `spawn` zones in the map ([maps.md](maps.md)) and by
event waves and summon abilities.

## World

```jsonc
"terrain": { "grass": { "walkable": true }, "forest": { "walkable": false }, ... },
"regions": [{
  "id": "goblinwood", "name": "Goblinwood", "levels": [1, 8],
  "map": "goblinwood.tmx", "playable": true, "description": "...",
  "waypoints": [{ "id": "buckleburg_gate", "name": "Buckleburg Gate" }, ...],
  "startWaypoint": "buckleburg_gate",    // where new heroes begin
  "loadingTips": ["Goblins are allergic to arrows."],
  "deathQuips": ["Probably the goblins' fault."]
}],
"resources": [{
  "id": "copper_vein", "name": "Copper Vein",
  "skill": "mining", "verb": "Mining",   // Day Job and prompt text
  "item": "copper_ore", "amount": [1, 2],
  "gatherTime": 1.6, "respawn": 90, "xp": 10,
  "prop": "ore_copper", "depletedProp": "ore_copper_depleted", "icon": "interact_mine"
}],
"dayJobs": [{
  "id": "mining", "name": "Mining", "icon": "skill_mining", "maxLevel": 10,
  "xpBase": 30,                  // xp to next level = xpBase × level × 1.5
  "speedPerLevel": 0.06,         // gathering gets faster (down to 40% of the time)
  "doubleChancePerLevel": 0.05,  // chance of a double yield
  "flavor": "Yes, enemies can interrupt you."
}],
"events": [{
  "id": "wagon_wheel_wipeout", "name": "Wagon Wheel Wipeout", "description": "...",
  "type": "defend",
  "zone": "wagon_defense",       // an `event` zone in the map
  "target": { "name": "Pip's Wagon", "hp": 360, "radius": 1.2, "prop": "wagon_broken" },
  "duration": 80, "level": 3,
  "waves": [{ "at": 2, "pack": "goblin_scouts" }, { "at": 16, "pack": "goblin_raiders" }],
  "spawnRadius": 9, "cooldown": 90, "loot": "event_wagon", "xp": 150,
  "npc": "pip_puddlefoot",               // who shouts the barks
  "startPrompt": "Defend the wagon!",    // dialog button to (re)start it
  "runningText": "They're HERE! Do the shooty thing!",
  "startBark": "...", "successBark": "...", "failBark": "..."
}],
"potion": { "name": "Questionable Health Potion", "icon": "ability_potion",
            "charges": 3, "maxCharges": 5, "heal": 0.4, "cooldown": 8, "description": "..." },
"healthOrb": { "heal": 0.12, "radius": 0.9, "lifetime": 20 }
```

Terrain ids match the Wang terrain names in the map's tileset; unwalkable
terrain blocks movement. A defend event succeeds when every wave has
spawned and been defeated before `duration` runs out, and fails if the
target breaks or time runs out. It can run again after `cooldown` seconds
(30 after a failure). Events start when their quest is accepted, or from the
quest giver's dialog (`startPrompt`).

Region flavor (`loadingTips`, `deathQuips`) feeds the loading screen and the
death screen. Code never names a specific region, NPC or monster in player
text; it reads names and jokes from here.

## Sprites

Every `sprite` id above names `assets/images/sprites/<id>.png` plus
`<id>.json`. The JSON describes frames, anchor and animations; see
[art.md](art.md#sprite-sheets). `validate()` checks that each ability's
`animation` exists on the sprites that use it.

## Checklist for new content

1. Add the definitions to the JSON files.
2. If you added a new kind of reference, add a check to `GameData.validate()`.
3. Run `flutter test test/content`.
4. Place it in the world (a spawn zone, loot table, NPC or quest) and try it
   with `?at=<waypoint>`.
5. Update the matching doc if you added a field.
