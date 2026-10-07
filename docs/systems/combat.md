# Combat

Combat is real time, in world space. Every hero and enemy ability is a JSON
definition in `game_data/abilities.json`, run by one engine:
`AbilityRunner` (`lib/game/combat/ability_runner.dart`). Damage and healing
happen in exactly one place: `CombatSystem.hit` / `heal`
(`lib/game/combat/combat_system.dart`).

## Flow of a cast

1. **Request.** For heroes, input becomes an `AbilityRequest`. Presses are
   buffered for 0.4 s (`InputState.bufferWindow`), so a skill pressed during
   another action still fires. Skills and the dodge cut a basic attack short;
   the dodge also cuts a skill's follow-through. Enemies choose abilities in
   `EnemyBrain`.
2. **Checks.** Unlocked by level, off cooldown, ultimate meter full (for
   `"resource": "ultimate"`), not stunned, not already casting.
3. **Begin.** The cooldown starts (heroes' cooldown reduction applies; not to
   ultimates), the animation plays and enemies show a telegraph. An
   `AbilityCast` holds the wind-up (`castTime`; hero basic attacks are divided
   by attack speed).
4. **Release.** After the wind-up the behavior runs (below). Hero casts then
   recover for 0.06 s, enemy casts for 0.35 s.
5. **Hit.** Projectiles and areas call `CombatSystem.hit`.

## Damage

```
damage = attacker.attack × ability multiplier × (1 + damage bonus)
         × difficulty damage            (enemy attackers only)
         × (1 + critDamage)             (on a crit)
         × armor mitigation
         × target vulnerability          (1.5 during a boss break window)
         × hero damage reduction         (powers like Hard Headed)
         × random 0.92–1.08
mitigation = 1 − armor / (armor + armorBase + armorPerAttackerLevel × attacker level)
```

`armorBase` (60) and `armorPerAttackerLevel` (12) live in
`progression.json`. Damage is rounded, minimum 1. Each direct hit flashes the
target briefly and shows a floating number (gold with `!` for crits, red on
the hero). Damage-over-time ticks show smaller numbers and don't flash.

Bosses only take damage during their fight; a hero hit from inside the arena
starts the fight, a hit from outside does nothing.

## Ultimate meter

Heroes fill the meter by hitting (each ability's `chargeGain` per hit) and by
taking hits (`ultimate.onHurt` in `progression.json`). It holds
`ultimate.max` (100). The ultimate needs a full meter and empties it.

## Ability fields

Common fields:

| Field | Meaning |
| --- | --- |
| `id`, `name`, `description`, `icon` | Identity and tooltip. `icon` names `assets/images/icons/<icon>.png` |
| `behavior` | What it does (table below) |
| `aim` | Touch aiming: `direction`, `line`, `cone`, `ground` or `self` |
| `target` | `aim` (default) or `self` for areas centred on the caster |
| `resource` | `cooldown` (default) or `ultimate` |
| `cooldown`, `castTime` | Seconds |
| `animation`, `releaseAnimation` | Sprite animations for the wind-up and the release |
| `range` | Tiles |
| `autoTarget` | Tap-to-cast auto-aim radius (0 = off) |
| `damage` | Multiplier of the caster's attack per hit |
| `effects` | Statuses applied on hit: `[{ "status": "root", "duration": 2.2, "amount": 0 }]` |
| `knockback` | Push strength on hit |
| `telegraph` | Enemy warning: `{ "shape": "cone" \| "line" \| "circle", "time": 1.0 }` |
| `chargeGain` | Ultimate meter gained per hit (heroes) |
| `bark` | Line the caster shouts (summons, buffs, heals) |

### Behaviors

| Behavior | Extra fields | Notes |
| --- | --- | --- |
| `projectile` | `projectile: { sprite, speed, radius, pierce }` | One projectile toward the aim. `pierce` = extra targets (999 = all) |
| `projectile_fan` | `projectile`, `count`, `spread` (degrees) | Evenly spaced fan |
| `ground_area` | `radius`, `delay`, `duration`, `tickInterval`, `tickDamage`, `visual` | An area at the aim point (clamped to `range`) or on the caster. `damage` hits once after `delay`, then `tickDamage` every `tickInterval` for `duration` |
| `multi_area` | `count`, `spread`, `radius`, `delay`, `includeSelf`, `visual` | Several areas scattered around the target, optionally one under the caster |
| `dash` | `distance`, `duration`, `invulnerable` | Heroes dash toward their movement, or backwards when standing still |
| `melee_arc` | `range`, `arc` (degrees) | Hits every opponent in the cone |
| `charge` | `range`, `width`, `speed`, `wallStun` | Runs in a line hitting everything once. Hitting a wall stuns the charger for `wallStun` seconds and makes it take +50% damage (a break window) |
| `heal_allies` | `radius`, `amount` (fraction of max HP), `threshold` | Enemy AI casts it when an ally in range drops below `threshold` health |
| `summon` | `pack`, `radius`, `damage`, `knockback` | Spawns a pack around the caster; with `knockback`, also blasts nearby opponents |
| `buff_self` | `buff: { attackSpeed, moveSpeed, cooldownRate, rage }` | Permanent multipliers (`rage` tints the caster red) |

`summon` and `buff_self` are used as phase `onEnter` abilities. Enemy AI never
picks them on its own. A `summon` with knockback is a blast: give it a
`"telegraph": { "shape": "circle" }` to draw its radius around the caster
during the wind-up. (`ground_area` and `multi_area` draw their own warning
circles during `delay`.)

Area visuals (`visual`): `vines`, `arrow_rain`, `slam`, `rocks`, `hex`.
Projectile sprites: `arrow`, `golden_arrow`, `rock`, `hex_bolt`. New visuals
need drawing code in `area_effect.dart` or `projectile.dart`.

Example, the Ranger's Vine Trap:

```json
{
  "id": "ranger_vine_trap", "name": "Vine Trap", "icon": "ability_vine_trap",
  "behavior": "ground_area", "aim": "ground", "cooldown": 11, "castTime": 0.3,
  "animation": "cast", "range": 7, "autoTarget": 8, "radius": 1.7, "delay": 0.25,
  "duration": 2.4, "tickInterval": 0.5, "damage": 0.6, "tickDamage": 0.15,
  "visual": "vines", "effects": [{ "status": "root", "duration": 2.2 }], "chargeGain": 2
}
```

## Statuses

`lib/game/combat/status_effects.dart`. Reapplying keeps the longer duration.

| Status | Effect |
| --- | --- |
| `root` | Can't move; can still act |
| `stun` | Can't move or act; interrupts casts |
| `slow` | Move speed × (1 − `amount`) |
| `burn` | `amount` damage per second |

Bosses resist 60% of crowd-control duration and elites 35%; both ignore
knockback.

## Dodge

Every hero has a `dodgeAbility` (the Ranger's Backflip: a 3.2-tile dash,
invulnerable for its 0.34 s). Dashes go through enemies, not walls.

## Enemy AI

`EnemyBrain` (`lib/game/ai/enemy_brain.dart`) runs idle → chase → return:

- **Idle**: wander near home. Aggro when the hero comes within `aggroRange`,
  but never while the hero stands within 5 tiles of a waypoint stone
  (waypoints are sanctuaries; damage still pulls monsters). A pulled enemy
  calls pack mates within 6 tiles.
- **Chase**: pick the first ready ability that fits (in range, line of sight
  for projectiles, a hurt ally for heals), otherwise move. Ranged and caster
  enemies keep `preferredRange`. Chasers use the hero flow field to path
  around obstacles, and packs spread out instead of stacking.
- **Return**: past `leashRange` from home, walk back and heal up. Bosses in a
  fight and event attackers never leash.
- **Phases**: phased enemies switch ability lists at health thresholds and
  cast the phase's `onEnter` ability once.

Telegraph rules: every boss attack that hurts has a wind-up with a
telegraph. Enemy animations are stretched so the strike frame lands on the
hit.

## Legendary powers

A legendary item (`items.json`) carries a `power` with an `id`, the
`ability` it changes and `params`. Code hooks look powers up with
`PowerSet.forAbility(id, abilityId)` (`lib/game/combat/powers.dart`), so a
hook only fires for the ability the item names.

| Power | Ability | Effect |
| --- | --- | --- |
| `stormcaller` | Precision Shot | The first hit chains lightning to `chains` nearby enemies |
| `chewed_volley` | Multi-Shot | `extra` arrows, `spreadBonus` degrees wider |
| `flair_trap` | Backflip | Leaves a rooting vine patch (every `cooldown` s) |
| `hard_headed` | (any) | Take `reduction` less damage below `threshold` health |
| `bear_necessities` | Arrow Storm | Radius +`radiusBonus`, and its slow becomes `slow` |
| `double_tap` | Quick Shot | `chance` to fire a second arrow |

To add a power: give the legendary a new `power.id` and `params` in
`items.json`, then read it with `forAbility` where the behavior changes
(`ability_runner.dart` or `hero.dart`).

## Tests

`test/game/game_smoke_test.dart` casts every hero ability, kills goblins,
checks the input buffer and fights the boss.
