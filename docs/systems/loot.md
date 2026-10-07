# Loot and items

> Gear should change how you play. Legendaries matter because they alter
> abilities, not because they add 2.7% to something nobody notices.

Definitions live in `game_data/items.json` and `game_data/loot_tables.json`.
Rolling happens in `ItemFactory` (`lib/rules/items.dart`) and `LootRoller`
(`lib/rules/loot.dart`); both take an optional seeded `Random` for tests.

## items.json

### Rarities

| Id | Affixes | Weight | Stat × | Sell × | Salvage (Shiny Bits) |
| --- | --- | --- | --- | --- | --- |
| common | 0 | 52 | 1.00 | 1 | 0 |
| uncommon | 1 | 30 | 1.08 | 2 | 1 |
| rare | 2 | 13.5 | 1.16 | 4 | 2 |
| epic | 3 | 3.6 | 1.26 | 8 | 4 |
| legendary | 3 | 0.9 | 1.38 | 20 | 10 |

`weight` drives random rarity; `statMult` scales the base's implicit stat;
`color` is the UI color.

### Slots and stats

Slots: `weapon`, `head`, `chest`, `hands`, `feet`, `trinket`.

Stats (`format` controls display): `maxHp`, `attack`, `armor` (flat);
`hpRegen` (per second); `critChance`, `critDamage`, `attackSpeed`,
`moveSpeed`, `cooldownReduction`, `damageBonus`, `goldFind`, `ultimateCharge`
(percent, stored as fractions: 0.08 = 8%).

### Bases

```json
{ "id": "short_bow", "name": "Short Bow", "slot": "weapon", "classes": ["ranger"],
  "icon": "item_bow", "levels": [1, 5],
  "implicit": { "stat": "attack", "range": [6, 9], "perLevel": 2.0 } }
```

A base drops when the item level is inside `levels`, for the listed hero
classes (empty `classes` = anyone). Every item has its base's implicit stat.

### Affixes

```json
{ "id": "hearty", "stat": "maxHp", "range": [8, 14], "perLevel": 3,
  "prefix": "Hearty", "suffix": "of Vitality", "slots": ["head", "chest", "hands", "feet", "trinket"] }
```

An item gets `rarity.affixes` different affixes allowed in its slot. Values
roll in `range + perLevel × (level − 1)`.

### Names

- Common: the base name ("Short Bow").
- Uncommon: prefix + base ("Hearty Leaf Tunic").
- Rare: prefix + base + suffix ("Hearty Leaf Tunic of Vitality").
- Epic: `epicNames` adjective + base + "of" + noun ("Goblin-Bane Archer
  Gloves of Second Breakfast").
- Legendary: its own name.

### Legendaries

```json
{
  "id": "stormwood_bow", "name": "Stormwood Bow", "base": "hunting_bow",
  "icon": "item_bow_legendary", "level": 6,
  "fixed": { "attack": 42, "critChance": 0.08 },
  "power": {
    "id": "stormcaller", "name": "Stormcaller", "ability": "ranger_precision_shot",
    "description": "Precision Shot chains lightning to 2 nearby enemies after the first hit.",
    "params": { "chains": 2, "damage": 0.6, "range": 4.5 }
  },
  "flavor": "Carved from a tree that was struck by lightning. Twice. It took it personally."
}
```

A legendary has its base's implicit at the top of its range × the legendary
multiplier, plus its `fixed` stats (±10%, so two drops differ). Its item level
is at least `level`. The `power` is what makes it legendary; see
[combat.md](combat.md#legendary-powers) for how powers hook into abilities.

| Legendary | Slot | Power |
| --- | --- | --- |
| Stormwood Bow | weapon | Stormcaller: Precision Shot chains lightning |
| Gnawed Goblin Quiver | trinket | Chewed Volley: Multi-Shot fires more arrows |
| Boots of Unnecessary Flair | feet | Flair Trap: Backflip leaves rooting vines |
| Snagtooth's Iron Hood | head | Hard Headed: less damage at low health |
| Grizzlefang's Fang Necklace | trinket | Bear Necessities: bigger, slower Arrow Storm |
| Hilda's Spare Gloves | hands | Double Tap: Quick Shot sometimes fires twice |

### Materials

```json
{ "id": "copper_ore", "name": "Copper Ore", "icon": "mat_copper_ore", "description": "..." }
```

Materials come from gathering and loot, stack in the inventory and are used
by quests (`collect` objectives). Crafting will use them later.

## Loot tables

```json
{
  "id": "boss_grizzlefang",
  "gold": { "chance": 1, "range": [200, 260], "perLevel": 8 },
  "items": { "rolls": 4, "chance": 1, "rarityWeights": { "rare": 45, "epic": 40, "legendary": 15 } },
  "unique": { "chance": 1, "pool": ["grizzlefang_fang_necklace", "stormwood_bow"] },
  "materials": [{ "item": "grizzly_honey", "chance": 1, "amount": [2, 3] }],
  "healthOrb": 1,
  "shinyBits": { "chance": 1, "range": [5, 8] }
}
```

Every part is optional:

- `gold`: rolled once with `chance`; amount from `range` (+`perLevel` per
  level above 1) × difficulty gold × (1 + gold find).
- `items`: `rolls` attempts, each succeeding with `chance`. Rarity uses
  `rarityWeights` if given, otherwise the global weights. Higher difficulties
  boost each rarity tier above common by `(1 + rarityBonus)^tier`.
- `unique`: with `chance`, one legendary from `pool`.
- `materials`: each entry rolls separately.
- `healthOrb`: chance to drop an orb that heals `healthOrb.heal` of max HP
  (`world.json`).
- `shinyBits`: chance and amount.

A random `legendary` rarity roll picks any legendary the hero can use whose
`level` is at most item level + 2.

Tables are referenced by enemies (`loot`), chests (the map's `loot`
property), events (`loot`) and bosses. Current tables: `goblin_common`,
`goblin_shaman`, `goblin_minion`, `elite_snagtooth`, `boss_grizzlefang`,
`hollow_chest`, `event_wagon`.

## Drops in the world

`DungeonRealmsGame.dropLoot` scatters drops as `LootDrop` entities that
the hero picks up by walking over them. Gold, Shiny Bits, materials and
health orbs are pulled toward a hero who comes close. Items glow in their
rarity color and toast their name when picked up; epic and legendary drops
flash when they land, and a legendary also gets a banner. With a full bag
(30 slots) items stay on the ground. Drops vanish after three minutes, health
orbs after `healthOrb.lifetime`.

## Inventory, selling and salvage

`Inventory` (`lib/rules/inventory.dart`) holds the bag, equipped items (one
per slot), materials, gold and Shiny Bits.

- **Equip**: from the inventory panel; the hero's stats update at once. Green
  arrows mark bag items that beat what's equipped (by `itemScore`).
- **Sell** at Pip's trading post: `4 + level × 3 × rarity sell multiplier`
  gold.
- **Salvage** at Hilda's bench: the rarity's `salvage` value in Shiny Bits.
