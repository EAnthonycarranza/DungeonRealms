import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../../rules/stats.dart';
import '../dungeon_realms_game.dart';
import '../entities/actor.dart';
import '../entities/enemy.dart';
import '../entities/hero.dart';
import '../fx/fx.dart';

/// The single damage pipeline. Every hit in the game goes through [hit] so
/// crits, armor, difficulty, powers and quest hooks behave identically.
class CombatSystem {
  CombatSystem(this.game) : math_ = DamageMath(game.data.progression);

  final DungeonRealmsGame game;
  final DamageMath math_;
  final _rng = math.Random();

  /// Deals [multiplier] x attack damage from [source] to [target].
  /// Returns the damage actually dealt.
  double hit(
    Actor source,
    Actor target,
    double multiplier, {
    bool canCrit = true,
    List<StatusSpec> effects = const [],
    double knockback = 0,
    Vector2? knockDir,
    double chargeGain = 0,
    bool tick = false,
    String? abilityId,
  }) {
    if (!target.alive || target.isInvulnerable || multiplier <= 0) return 0;
    // Bosses only take damage in their fight; a hit from inside the arena
    // starts it, a hit from outside bounces off.
    if (target is EnemyEntity && target.def.isBoss && !target.engaged) {
      game.bosses.provoke(target, source);
      if (!target.engaged) return 0;
    }
    var dmg = source.attack * multiplier * (1 + source.damageBonus);
    if (source.faction == Faction.enemy) dmg *= game.difficulty.damage;
    final crit = canCrit && _rng.nextDouble() < source.critChance;
    if (crit) dmg *= 1 + source.critDamage;
    dmg *= math_.mitigation(target.armor, source.level);
    dmg *= target.vulnerability;
    if (target is HeroEntity) dmg *= target.incomingDamageMultiplier;
    // A little variance keeps numbers lively.
    dmg *= 0.92 + _rng.nextDouble() * 0.16;
    final amount = math.max(1, dmg.roundToDouble()).toDouble();

    target.hp -= amount;
    // Damage-over-time ticks don't flash, so a burning boss stays readable.
    if (!tick) target.flash = 0.09;
    target.sinceHurt = 0;
    target.sinceCombat = 0;
    source.sinceCombat = 0;
    for (final e in effects) {
      target.statuses.apply(e);
    }
    if (knockback > 0 && !target.knockbackImmune && knockDir != null) {
      target.knockback.addScaled(knockDir, knockback * 6);
    }

    // Feedback.
    final isHero = target is HeroEntity;
    final color = isHero
        ? const Color(0xffff5b4d)
        : crit
        ? const Color(0xffffd23f)
        : const Color(0xfffff6e0);
    game.floatText(target, crit ? '${amount.toInt()}!' : '${amount.toInt()}', color, size: crit ? 30 : (tick ? 17 : 22));
    if (!tick) {
      final p = target.position;
      game.particles.emit(
        x: p.x,
        y: p.y - target.visualHeight * 0.55 - target.z,
        color: isHero ? const Color(0xffff8a7a) : const Color(0xfffff1c7),
        count: crit ? 10 : 5,
        speed: crit ? 200 : 140,
        life: 0.25,
        size: 3,
        shape: ParticleShape.spark,
      );
    }
    if (crit && !isHero) game.shake(2);

    // Ultimate charge.
    final hero = game.hero;
    if (source == hero && chargeGain > 0) hero.gainCharge(chargeGain);
    if (target == hero) {
      hero.gainCharge(game.data.progression.ultimateOnHurt);
      hero.onHurt(amount, source);
    }
    if (target is EnemyEntity) target.onDamaged(source, amount);

    if (target.hp <= 0) kill(target, source);
    return amount;
  }

  void applyBurn(Actor target, double damage) {
    if (!target.alive) return;
    target.hp -= damage;
    if (target.hp <= 0) kill(target, null);
  }

  void heal(Actor target, double amount, {bool showText = true}) {
    if (!target.alive || amount <= 0) return;
    final before = target.hp;
    target.hp = math.min(target.maxHp, target.hp + amount);
    final gained = target.hp - before;
    if (showText && gained >= 1) {
      game.floatText(target, '+${gained.round()}', const Color(0xff82f16d), size: 18);
    }
  }

  void kill(Actor target, Actor? killer) {
    if (target.dead) return;
    target.hp = 0;
    target.onDeath();
    final p = target.position;
    game.particles.emit(
      x: p.x,
      y: p.y - target.visualHeight * 0.4,
      color: const Color(0xffe8e2d0),
      count: 14,
      speed: 160,
      life: 0.6,
      size: 6,
      gravity: -40,
      drag: 3,
    );
    if (target is EnemyEntity) {
      game.onEnemyKilled(target, killer);
    } else if (target is HeroEntity) {
      game.onHeroKilled(killer);
    } else {
      game.onActorKilled(target);
    }
  }
}
