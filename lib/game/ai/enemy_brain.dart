import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../content/game_data.dart';
import '../entities/actor.dart';
import '../entities/enemy.dart';

/// Decision making for one enemy. Behaviour is selected by `EnemyDef.ai`:
///
/// * `melee`  - close in and hit.
/// * `ranged` - keep [EnemyDef.preferredRange], back off when crowded.
/// * `caster` - heal hurt allies first, then hex the target.
/// * `phased` - elites/bosses: ability lists per health phase, with an
///   `onEnter` ability fired when a phase begins.
class EnemyBrain {
  EnemyBrain(this.e);

  final EnemyEntity e;
  final _rng = math.Random();
  String state = 'idle';
  double _think = 0;
  double _losTimer = 0;
  bool _los = true;
  double _wander = 0;
  Vector2? _wanderTarget;
  double _barkCooldown = 0;
  final _move = Vector2.zero();
  final _tmp = Vector2.zero();

  EnemyDef get def => e.def;
  bool get _phased => def.ai == 'phased';

  void onDamaged(Actor source) {
    if (e.target == null || state != 'chase') _aggro(source, assist: true);
  }

  void _aggro(Actor target, {bool assist = false}) {
    if (def.isBoss && !e.engaged) return;
    final first = e.target == null;
    e.target = target;
    state = 'chase';
    if (first && _barkCooldown <= 0 && def.barks.isNotEmpty && (def.isElite || def.isBoss || _rng.nextDouble() < 0.35)) {
      e.say(def.barks[_rng.nextInt(def.barks.length)]);
      _barkCooldown = 8;
    }
    if (assist) {
      // Pack members join the fight.
      for (final other in e.game.enemies) {
        if (other == e || !other.alive || other.target != null) continue;
        if (other.ground.distanceTo(e.ground) < 6) other.brain._aggro(target);
      }
    }
  }

  void update(double dt) {
    _barkCooldown -= dt;
    _losTimer -= dt;
    final game = e.game;
    if (e.statuses.stunned || e.cast != null || e.isDashing) return;

    // Phases (elites & bosses).
    if (_phased && e.target != null) {
      final phases = def.phases;
      while (e.phaseIndex + 1 < phases.length && e.hpFraction <= phases[e.phaseIndex + 1].from) {
        e.phaseIndex++;
        final enter = phases[e.phaseIndex].onEnter;
        if (enter != null) {
          final a = game.data.abilities[enter]!;
          if (game.abilities.begin(e, a, aimPoint: e.target!.ground.clone(), target: e.target)) {
            game.onBossPhase(e, e.phaseIndex);
            return;
          }
        }
      }
    }

    final hero = game.hero;
    // Target acquisition.
    if (e.target == null || !e.target!.alive) {
      e.target = null;
      if (state == 'chase') state = 'return';
      if (e.eventTarget != null && e.eventTarget!.alive) {
        _aggro(e.eventTarget!);
      } else if (hero.alive && (!def.isBoss || e.engaged)) {
        final d = hero.ground.distanceTo(e.ground);
        if (d < def.aggroRange && !game.inSanctuary(hero.ground)) _aggro(hero, assist: true);
      }
    } else if (e.eventTarget != null && e.target == e.eventTarget && hero.alive && hero.ground.distanceTo(e.ground) < 3.5) {
      e.target = hero;
    }

    // Leash back home (not during events or boss fights).
    if (state == 'chase' && e.eventTarget == null && !(def.isBoss && e.engaged)) {
      if (e.ground.distanceTo(e.home) > def.leashRange) {
        state = 'return';
        e.target = null;
      }
    }

    switch (state) {
      case 'idle':
        _idle(dt);
      case 'return':
        _return(dt);
      default:
        _chase(dt);
    }
  }

  void _idle(double dt) {
    _wander -= dt;
    if (_wander <= 0) {
      _wander = 2.5 + _rng.nextDouble() * 4;
      if (_rng.nextDouble() < 0.55 && !def.isBoss) {
        final a = _rng.nextDouble() * math.pi * 2;
        _wanderTarget = e.home + Vector2(math.cos(a), math.sin(a)) * (0.5 + _rng.nextDouble() * 2.2);
      } else {
        _wanderTarget = null;
      }
    }
    final t = _wanderTarget;
    if (t != null && e.ground.distanceTo(t) > 0.25 && e.canMove) {
      _walkToward(t, dt, speedScale: 0.45, avoid: false);
    } else {
      e.playAnim('idle');
    }
  }

  void _return(double dt) {
    if (e.ground.distanceTo(e.home) < 0.6 || !e.canMove) {
      state = 'idle';
      e.hp = e.maxHp;
      e.phaseIndex = 0;
      e.playAnim('idle');
      return;
    }
    e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.25 * dt);
    _walkToward(e.home, dt, speedScale: 1.2, avoid: true);
  }

  List<String> get _abilityIds => _phased ? def.phases[e.phaseIndex].abilities : def.abilities;

  void _chase(double dt) {
    final target = e.target;
    if (target == null) {
      state = 'return';
      return;
    }
    final game = e.game;
    final dist = e.ground.distanceTo(target.ground);
    _think -= dt;
    if (_think <= 0) {
      _think = 0.12 + _rng.nextDouble() * 0.1;
      if (_tryAbility(target, dist)) return;
    }
    if (!e.canMove) {
      e.playAnim('idle');
      return;
    }
    final pref = def.preferredRange;
    if (pref > 0) {
      if (dist < pref - 1.8) {
        // Too close: back away (kiting).
        _tmp.setFrom(e.ground - target.ground);
        if (_tmp.length2 < 1e-6) _tmp.setValues(1, 0);
        _tmp.normalize();
        _step(_tmp, dt, speedScale: 0.85);
        e.faceDirection(target.ground - e.ground);
        return;
      }
      if (dist <= pref + 0.4 && _hasLos(target)) {
        e.faceDirection(target.ground - e.ground);
        e.playAnim('idle');
        return;
      }
    } else {
      final reach = _meleeReach() + target.radius;
      if (dist <= reach * 0.85) {
        e.faceDirection(target.ground - e.ground);
        e.playAnim('idle');
        return;
      }
    }
    _walkToward(target.ground, dt, speedScale: 1, avoid: true, useFlow: target == game.hero);
  }

  double _meleeReach() {
    var best = 1.0;
    for (final id in _abilityIds) {
      final a = e.game.data.abilities[id]!;
      if (a.behavior == AbilityBehavior.meleeArc) best = math.max(best, a.range);
    }
    return best;
  }

  bool _hasLos(Actor target) {
    if (_losTimer <= 0) {
      _losTimer = 0.35;
      _los = e.game.collision.clearPath(e.ground, target.ground, 0.15);
    }
    return _los;
  }

  bool _tryAbility(Actor target, double dist) {
    final game = e.game;
    for (final id in _abilityIds) {
      final a = game.data.abilities[id]!;
      if (!e.ready(a)) continue;
      var ok = false;
      switch (a.behavior) {
        case AbilityBehavior.meleeArc:
          ok = dist <= a.range + target.radius;
        case AbilityBehavior.projectile:
        case AbilityBehavior.projectileFan:
          ok = dist <= a.range * 0.92 && _hasLos(target);
        case AbilityBehavior.groundArea:
          ok = a.target == 'self' ? dist <= a.radius + target.radius : dist <= a.range;
        case AbilityBehavior.multiArea:
          ok = dist <= 8;
        case AbilityBehavior.charge:
          ok = dist >= 3.2 && dist <= a.range && _hasLos(target);
        case AbilityBehavior.healAllies:
          ok = game.alliesOf(e).any((ally) => ally.alive && ally.hpFraction < 0.7 && ally.ground.distanceTo(e.ground) <= a.radius);
        case AbilityBehavior.summon:
        case AbilityBehavior.buffSelf:
          ok = false; // Only via phase onEnter.
        case AbilityBehavior.dash:
          ok = false;
      }
      if (!ok) continue;
      // Aim: lead moving targets slightly for projectiles.
      final aim = target.ground.clone();
      if (a.projectile != null && target == game.hero) {
        final lead = dist / a.projectile!.speed;
        aim.addScaled(game.hero.moveIntent, game.hero.moveSpeed * lead * 0.6);
      }
      if (game.abilities.begin(e, a, aimPoint: aim, target: target)) return true;
    }
    return false;
  }

  void _walkToward(Vector2 goal, double dt, {required double speedScale, required bool avoid, bool useFlow = false}) {
    final game = e.game;
    _move.setFrom(goal - e.ground);
    if (_move.length2 < 1e-6) return;
    _move.normalize();
    if (useFlow && !_hasLos(e.target!)) {
      final flow = game.heroFlow?.direction(e.ground, _tmp);
      if (flow != null) _move.setFrom(flow);
    }
    _step(_move, dt, speedScale: speedScale, avoid: avoid);
  }

  void _step(Vector2 dir, double dt, {required double speedScale, bool avoid = true}) {
    final game = e.game;
    if (avoid) {
      // Separation from other enemies so packs fan out instead of stacking.
      for (final other in game.enemies) {
        if (other == e || !other.alive) continue;
        final d = e.ground - other.ground;
        final min = e.radius + other.radius + 0.15;
        final l2 = d.length2;
        if (l2 > 1e-6 && l2 < min * min) {
          final l = math.sqrt(l2);
          dir.addScaled(d, (min - l) / l * 1.6);
        }
      }
      if (dir.length2 > 1e-6) dir.normalize();
    }
    final speed = e.moveSpeed * e.statuses.moveMultiplier * speedScale;
    e.moveBy(dir * (speed * dt));
    e.faceDirection(dir);
    e.playAnim('walk', speed: (speed / 3.2).clamp(0.5, 1.5));
  }
}
