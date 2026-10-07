# Quests and NPCs

Quests live in `game_data/quests.json`, NPCs in `game_data/npcs.json`.
`QuestLog` (`lib/rules/quest_log.dart`) tracks state and progress;
`QuestDirector` (`lib/game/systems/quest_director.dart`) runs NPC dialog,
accepting, turning in and services.

## Quest format

```json
{
  "id": "goblins_in_my_woods",
  "name": "Goblins? In MY Woods?",
  "giver": "captain_bramble",
  "requires": [],
  "summary": "Captain Bramble would like fewer goblins. Any fewer.",
  "objectives": [{ "type": "kill", "tag": "goblin", "count": 6, "text": "Bonk goblins" }],
  "rewards": { "xp": 300, "gold": 40, "items": [{ "base": "hunting_bow", "rarity": "rare" }] },
  "dialog": {
    "offer": "Goblins have been wandering out of Goblinwood again...",
    "accept": "Six goblins. Got it.",
    "progress": "Still counting goblins? Lovely.",
    "complete": "Six goblins! The paperwork sings!"
  }
}
```

- `giver`: the NPC who offers it and takes the turn-in.
- `requires`: quests that must be completed first.
- `dialog.accept` is the label of the accept button.

### Objectives

| `type` | Fields | Progresses when |
| --- | --- | --- |
| `kill` | `enemy` or `tag`, `count` | An enemy with that id (or tag) dies |
| `collect` | `item`, `count`, `consume` | The inventory holds `count` of the material. With `consume`, turning in removes them |
| `event` | `event` | The public event succeeds |
| `discover` | `target` | The hero enters a map `trigger` whose `discover` property is `target` |
| `open` | `target` | The hero opens the chest named `target` |
| `talk` | `npc` | The hero talks to that NPC |

Every objective has a `text` for the tracker. Collect progress follows the
inventory, so dropping below the count takes the quest back from ready to
active. A new objective type needs a progress hook in `QuestLog`, a call site
in the game, and a check in `GameData.validate()`.

### Rewards

| Field | Effect |
| --- | --- |
| `xp`, `gold`, `shinyBits` | Granted on turn-in |
| `potionCharges` | Adds potion slots, up to `potion.maxCharges` |
| `items` | `[{ "base": "...", "rarity": "rare" }]`: rolled at hero level + 1 (`base` optional) |
| `unique` | A legendary id |

## Quest states

```
locked ──requires done──▶ available ──accept──▶ active ⇄ ready ──turn in──▶ completed
```

`ready` means every objective is complete. The tracker shows active and ready
quests; NPCs show `!` over their heads when they have a quest to offer and `?`
when one is ready to turn in. Accepting a quest with an `event` objective
starts the event straight away.

## NPC dialog

Talking to an NPC (`QuestDirector.talk`) picks the quest to discuss in this
order: ready > available > active.

- **Ready**: `dialog.complete` and a *Complete quest* button. Turning in
  chains straight into the NPC's next available quest.
- **Available**: `dialog.offer`, the accept button and *Not now*.
- **Active**: `dialog.progress`. For an event quest whose event can run,
  the event's `startPrompt` button restarts it; while it runs, the NPC says
  the event's `runningText`.
- **No quest**: the NPC's `greeting`.

Then the NPC's services are added as extra buttons. The game pauses while the
dialog is open.

## NPCs

```json
{
  "id": "hilda_hammerbottom",
  "name": "Hilda Hammerbottom",
  "title": "Blacksmith",
  "sprite": "npc_hilda",
  "color": "#ff8a2b",
  "greeting": "Mind the anvil. It bites.",
  "barks": ["Copper! Bring me copper!"],
  "services": ["salvage"],
  "shop": { "title": "Hilda's Salvage Bench", "blurb": "Break gear into Shiny Bits..." }
}
```

- `color`: name color in the dialog panel.
- `barks`: lines the NPC says now and then when the hero is near.
- `services`:
  - `salvage`: opens the salvage panel (items → Shiny Bits).
  - `sell`: opens the sell panel (items → gold).
  - `refill_potions`: refills potions for free.
  - `respec_difficulty`: changes the world difficulty, once more than one
    tier is unlocked.
- `shop`: title and blurb of the `salvage` / `sell` panel.

NPCs are placed by `npc` objects in the map (property `npc` = the NPC id).

## Goblinwood's quests

| Quest | Giver | Requires | Objectives | Notable reward |
| --- | --- | --- | --- | --- |
| Goblins? In MY Woods? | Captain Bramble | | Kill 6 goblins | Rare Hunting Bow |
| Rock and Stone (Mostly Rock) | Hilda Hammerbottom | | Collect 4 Copper Ore | Hilda's Spare Gloves (legendary) |
| Sniff Responsibly | Granny Gristle | | Collect 5 Sniffleleaf | +1 potion slot |
| Wagon Wheel Wipeout | Pip Puddlefoot | | Win the wagon event | A rare item |
| Camp Crasher | Captain Bramble | Goblins? In MY Woods? | Find Snagtooth's camp, defeat Warboss Snagtooth | 900 XP |
| Nothing Suspicious Here | Granny Gristle | Sniff Responsibly | Find the suspicious hollow, open its chest | Shiny Bits |
| Absolutely Unbearable | Captain Bramble | Camp Crasher | Defeat Grizzlefang | 2000 XP |

## Saving

`QuestLog.toJson` stores only quests that have been accepted (state and
objective counts) in the hero profile; locked and available states are
recomputed from `requires` when the log loads.
