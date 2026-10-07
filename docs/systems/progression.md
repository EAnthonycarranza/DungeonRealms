# Progression

Tuning lives in `game_data/progression.json`; hero growth lives in
`heroes.json` and Day Jobs in `world.json`.

```jsonc
{
  "levelCap": 60,
  "startingGold": 15,
  "xpCurve": { "base": 80, "exponent": 1.6 },
  "ultimate": { "max": 100, "onHurt": 2 },
  "combat": {
    "armorBase": 60,                 // see combat.md, "Damage"
    "armorPerAttackerLevel": 12,
    "regenOutOfCombatDelay": 4,      // seconds without hitting or being hit
    "regenOutOfCombatPct": 0.04      // extra regen per second, fraction of max HP
  },
  "difficulties": [...],
  "mechanics": [...]
}
```

## Levels and XP

- XP to go from level `L` to `L + 1`: `round(base × L^exponent)`. With the
  current curve: 80, 243, 464, 735, 1051, 1406, 1800, 2229 for levels 1→9.
- XP comes from kills (the enemy's scaled XP × difficulty XP), quests and
  events. Goblinwood is tuned for levels 1–8.
- A level-up recomputes stats (base + growth × (level − 1) + gear), fully
  heals, and shows a banner. Hero abilities unlock at their slot's
  `unlockLevel` (the Ranger: Precision Shot 1, Multi-Shot 2, Vine Trap 3,
  Arrow Storm 4).
- XP stops at `levelCap`. Hero Rank (account progression after 60) is not
  built yet.

## Health, potions and death

- Heroes regenerate `hpRegen` per second, plus `regenOutOfCombatPct` of max HP
  per second after `regenOutOfCombatDelay` seconds out of combat.
- Potions (`world.json` `potion`) heal a fraction of max HP with a cooldown.
  Waypoints, respawning and Granny Gristle's service refill them; the Sniff
  Responsibly quest adds a slot (up to `maxCharges`).
- Health orbs dropped by enemies heal a fraction of max HP.
- Death shows the death screen; respawning puts the hero at the last waypoint
  with full health and potions and 2 s of invulnerability. A boss fight in
  progress resets. There is no XP or gold penalty.

## World difficulty

Defined in `progression.json` `difficulties`; chosen through Captain
Bramble's `respec_difficulty` service.

| Id | Name | HP × | Damage × | XP × | Gold × | Rarity bonus | Mechanics | Unlocked by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| normal | Normal | 1 | 1 | 1 | 1 | 0 | | |
| spicy | Spicy 🌶 | 1.6 | 1.35 | 1.5 | 1.4 | 0.4 | hot_sauce | `grizzlefang` (on Normal) |
| very_spicy | Very Spicy 🌶🌶 | 2.4 | 1.8 | 2.2 | 1.9 | 0.9 | + elite_packs | `spicy:grizzlefang` |
| ridiculous | Ridiculous 💀 | 3.8 | 2.5 | 3.2 | 2.6 | 1.6 | + angry_trees | `very_spicy:grizzlefang` |
| why | Why Would You Do This? 👑 | 6.0 | 3.4 | 4.5 | 3.5 | 2.5 | (same) | `ridiculous:grizzlefang` |

- `hp` and `damage` scale enemies; `xp` and `gold` scale rewards;
  `rarityBonus` pushes item rarities up (see [loot.md](loot.md#loot-tables)).
- `unlock` is a boss id (beaten on Normal) or `<difficulty>:<boss id>`. Boss
  kills are recorded per difficulty in the hero profile.
- Mechanics add rules, not just numbers (the vision's "difficulty tiers that
  add mechanics"):
  - `hot_sauce`: slain non-boss enemies leave a burning puddle for 3 s.
  - `elite_packs`: one member of every pack of two or more has double health,
    is bigger and glows.
  - `angry_trees`: placeholder, not implemented yet.

A new mechanic is an entry in `mechanics` plus a check for its id where it
applies (`difficulty.mechanics.contains('...')`).

## Day Jobs

`world.json` `dayJobs` define each job; `resources` define what can be
gathered.

- Interact with a resource node to gather for `gatherTime` seconds. Moving or
  getting hit cancels it (enemies interrupt you, as promised).
- Each gather gives `amount` of `item` and `xp` Day Job XP. XP to the next
  job level is `xpBase × level × 1.5`, up to `maxLevel`.
- Each job level gathers `speedPerLevel` faster (down to 40% of the time) and
  adds `doubleChancePerLevel` chance of a double yield.
- Nodes show their depleted prop and come back after `respawn` seconds.

Goblinwood has Mining (Copper Vein → Copper Ore) and Herbalism (Sniffleleaf).
Blacksmithing and Alchemy are on the [roadmap](../ROADMAP.md).
