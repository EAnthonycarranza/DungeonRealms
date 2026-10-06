import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../dungeon_realms_game.dart';
import '../entities/actor.dart';
import '../entities/enemy.dart';
import '../entities/hero.dart';
import '../fx/fx.dart';
import 'ability_cast.dart';
import 'area_effect.dart';
import 'powers.dart';
import 'projectile.dart';
import 'telegraph.dart';

/// Executes [AbilityDef]s for any actor. Behaviours are generic; abilities
/// are data. See docs/systems/combat.md before adding a new behaviour.
class AbilityRunner {
  AbilityRunner(this.game);

  final DungeonRealmsGame game;
  final _rng = math.Random();

  /// Starts casting [a] at [aimPoint]. Returns false if the caster is busy.
  bool begin(Actor caster, AbilityDef a, {required Vector2 aimPoint, Actor? target}) {
    if (!caster.alive || caster.statuses.stunned || caster.cast != null || caster.isDashing) return false;
    final dir = aimPoint - caster.ground;
    if (dir.length2 < 1e-6) dir.setFrom(caster.facing);
    dir.normalize();
    caster.faceDirection(dir);

    final isHero = caster is HeroEntity;
    final cdr = isHero ? caster.stats.cooldownReduction : 0.0;
    if (a.isUltimate) {
      if (caster is HeroEntity) caster.spendUltimate();
    }
    caster.startCooldown(a, reduction: a.isUltimate ? 0 : cdr);

    // Basic attacks speed up with attack speed.
    var castTime = a.castTime;
    if (isHero && a.id == caster.basicAbility?.id) castTime /= caster.stats.attackSpeed;
    final windup = castTime;

    // Animation timing: enemies stretch their wind-up so the strike frame
    // lands exactly when the hit resolves (readable telegraphs).
    final anim = a.animation;
    if (anim != null && caster.animator != null) {
      final meta = caster.animator!.sheet.meta.anim(anim);
      var speed = 1.0;
      if (meta != null && windup > 0) {
        final eventFrame = meta.events.values.isEmpty ? null : meta.events.values.first;
        if (eventFrame != null && !isHero) speed = (eventFrame / meta.fps) / windup;
        if (isHero && a.releaseAnimation == null) speed = math.max(1, (eventFrame ?? 3) / meta.fps / math.max(0.05, windup));
      }
      caster.playAnim(anim, restart: true, speed: speed.clamp(0.25, 3.0));
    }

    final lockedPoint = aimPoint.clone();
    final lockedDir = dir.clone();
    Component? telegraph;
    if (!isHero && a.telegraph != null && windup > 0) {
      telegraph = switch (a.telegraph!.shape) {
        'cone' => Telegraph.cone(origin: caster.ground.clone(), dir: lockedDir, range: a.range + 0.3, arcDegrees: a.arc, duration: windup),
        'line' => Telegraph.line(origin: caster.ground.clone(), dir: lockedDir, range: a.range, width: a.width, duration: windup),
        // Ground areas draw their own warning; blasts around the caster need one.
        'circle' when a.behavior == AbilityBehavior.summon => Telegraph.circle(origin: caster.ground.clone(), range: a.radius, duration: windup),
        _ => null,
      };
      if (telegraph != null) game.groundLayer.add(telegraph);
    }

    caster.cast = AbilityCast(
      ability: a,
      windup: windup,
      recovery: isHero ? 0.06 : 0.35,
      onRelease: () {
        telegraph?.removeFromParent();
        if (a.releaseAnimation != null) caster.playAnim(a.releaseAnimation!, restart: true, speed: 2);
        if (caster.animator != null && !isHero) caster.animator!.speed = 1;
        _execute(caster, a, lockedPoint, lockedDir, target);
      },
      onCancel: () => telegraph?.removeFromParent(),
    );
    if (windup <= 0) caster.cast!.update(0);
    return true;
  }

  Vector2 _muzzle(Actor caster, Vector2 dir) => caster.ground + dir * (caster.radius + 0.15);

  void _execute(Actor caster, AbilityDef a, Vector2 aimPoint, Vector2 dir, Actor? target) {
    if (!caster.alive) return;
    final hero = caster is HeroEntity ? caster : null;
    switch (a.behavior) {
      case AbilityBehavior.projectile:
        _fire(caster, a, dir);
        final doubleTap = hero?.powers.forAbility('double_tap', a.id);
        if (doubleTap != null && _rng.nextDouble() < doubleTap.param('chance', 0.25)) {
          game.after(0.09, () => _fire(caster, a, dir.clone()..rotate(0.05)));
        }
      case AbilityBehavior.projectileFan:
        var count = a.count;
        var spread = a.spread;
        final p = hero?.powers.forAbility('chewed_volley', a.id);
        if (p != null) {
          count += p.param('extra', 3).toInt();
          spread += p.param('spreadBonus', 18);
        }
        final base = math.atan2(dir.y, dir.x);
        final total = spread * math.pi / 180;
        for (var i = 0; i < count; i++) {
          final ang = count == 1 ? base : base - total / 2 + total * i / (count - 1);
          _fire(caster, a, Vector2(math.cos(ang), math.sin(ang)));
        }
      case AbilityBehavior.groundArea:
        final center = a.target == 'self' ? caster.ground.clone() : _clampToRange(caster, aimPoint, a.range);
        var radius = a.radius;
        var effects = a.effects;
        final bear = hero?.powers.forAbility('bear_necessities', a.id);
        if (bear != null) {
          radius *= 1 + bear.param('radiusBonus', 0.4);
          effects = [for (final e in effects) e.status == 'slow' ? StatusSpecOverride.slow(e, bear.param('slow', 0.6)) : e];
        }
        _area(caster, a, center, radius, effects);
        if (a.visual == 'vines' && hero != null) _seedToss(caster, center);
      case AbilityBehavior.multiArea:
        final focus = target?.ground.clone() ?? aimPoint;
        for (var i = 0; i < a.count; i++) {
          final ang = _rng.nextDouble() * math.pi * 2;
          final r = i == 0 ? 0.0 : (0.8 + _rng.nextDouble()) * a.spread * 0.5;
          final p = focus + Vector2(math.cos(ang), math.sin(ang)) * r;
          _area(caster, a, p, a.radius, a.effects);
        }
        if (a.includeSelf) _area(caster, a, caster.ground.clone(), a.radius * 1.3, a.effects);
      case AbilityBehavior.dash:
        _dash(caster, a, dir);
      case AbilityBehavior.meleeArc:
        _meleeArc(caster, a, dir);
      case AbilityBehavior.charge:
        _charge(caster, a, dir);
      case AbilityBehavior.healAllies:
        for (final ally in game.alliesOf(caster)) {
          if (ally.ground.distanceTo(caster.ground) > a.radius) continue;
          game.combat.heal(ally, ally.maxHp * a.amount);
          game.particles.emit(
            x: ally.position.x,
            y: ally.position.y - 30,
            color: const Color(0xff82f16d),
            count: 10,
            speed: 60,
            life: 0.8,
            size: 4,
            gravity: -80,
          );
        }
        if (a.bark != null) caster.say(a.bark!);
      case AbilityBehavior.summon:
        if (a.bark != null) caster.say(a.bark!, duration: 3);
        if (a.pack != null && caster is EnemyEntity) game.spawns.summonPack(a.pack!, around: caster.ground, level: caster.level, leader: caster);
        if (a.knockback > 0) {
          for (final enemy in game.opponentsOf(caster.faction)) {
            final away = enemy.ground - caster.ground;
            if (away.length < a.radius) {
              game.combat.hit(caster, enemy, a.damage, knockback: a.knockback, knockDir: away.length2 > 1e-6 ? away.normalized() : Vector2(1, 0));
            }
          }
          game.shake(6);
          game.particles.ring(caster.position.x, caster.position.y - 40, const Color(0xffffc94f), size: 140);
        }
      case AbilityBehavior.buffSelf:
        caster.actionSpeed *= 1 + (a.buff['attackSpeed'] ?? 0);
        caster.moveSpeed *= 1 + (a.buff['moveSpeed'] ?? 0);
        caster.cooldownRate *= 1 + (a.buff['cooldownRate'] ?? 0);
        if ((a.buff['rage'] ?? 0) > 0) caster.tint = const Color(0x44ff3b2d);
        if (a.bark != null) caster.say(a.bark!, duration: 3.5);
        game.shake(5);
        game.particles.ring(caster.position.x, caster.position.y - 60, const Color(0xffff5b2d), size: 160);
    }
  }

  Vector2 _clampToRange(Actor caster, Vector2 point, double range) {
    final d = point - caster.ground;
    if (d.length > range) d.scaleTo(range);
    return caster.ground + d;
  }

  void _fire(Actor caster, AbilityDef a, Vector2 dir) {
    final spec = a.projectile!;
    final hero = caster is HeroEntity ? caster : null;
    final storm = hero?.powers.forAbility('stormcaller', a.id);
    game.entityLayer.add(
      Projectile(
        owner: caster,
        ability: a,
        start: _muzzle(caster, dir),
        direction: dir,
        speed: spec.speed,
        range: a.range,
        multiplier: a.damage,
        pierce: spec.pierce,
        sprite: spec.sprite,
        radius: spec.radius,
        effects: a.effects,
        knockback: a.knockback,
        chargeGain: a.chargeGain,
        onHitHook: storm != null
            ? (p, target, index) {
                if (index == 0) chainLightning(game, caster, target, storm);
              }
            : null,
      ),
    );
  }

  void _area(Actor caster, AbilityDef a, Vector2 center, double radius, List<StatusSpec> effects) {
    game.groundLayer.add(
      AreaEffect(
        owner: caster,
        ability: a,
        center: center,
        radius: radius,
        delay: a.delay,
        duration: a.duration,
        tickInterval: a.tickInterval,
        damage: a.damage,
        tickDamage: a.tickDamage,
        effects: effects,
        visual: a.visual ?? 'none',
        knockback: a.knockback,
        telegraphed: caster.faction == Faction.enemy,
      ),
    );
  }

  /// A little seed arc so Vine Trap reads as "thrown".
  void _seedToss(Actor caster, Vector2 target) {
    final from = caster.position.clone()..y -= 40;
    final to = game.iso.toScreenV(target);
    game.overlay.add(SeedFx(from, to));
  }

  void _dash(Actor caster, AbilityDef a, Vector2 aimDir) {
    final dir = aimDir.clone();
    if (caster is HeroEntity) {
      final move = caster.moveIntent;
      if (move.length2 > 0.01) {
        dir.setFrom(move.normalized());
      } else {
        dir.setFrom(-caster.facing);
      }
      // Backflips go backwards: keep facing the old direction.
      final keepFacing = caster.facing.clone();
      caster.faceDirection(-dir);
      if (move.length2 > 0.01) caster.faceDirection(dir);
      if (move.length2 <= 0.01) caster.faceDirection(keepFacing);
      final flair = caster.powers.forAbility('flair_trap', a.id);
      if (flair != null && caster.flairCooldown <= 0) {
        caster.flairCooldown = flair.param('cooldown', 4);
        game.groundLayer.add(
          AreaEffect(
            owner: caster,
            ability: null,
            center: caster.ground.clone(),
            radius: flair.param('radius', 1.4),
            delay: 0.15,
            duration: 1.6,
            tickInterval: 0.5,
            damage: 0.3,
            tickDamage: 0.1,
            effects: [StatusSpecOverride.root(flair.param('root', 1.6))],
            visual: 'flair_vines',
          ),
        );
      }
    }
    caster.dashVelocity.setFrom(dir * (a.distance / a.duration));
    caster.dashTime = a.duration;
    caster.dashInvulnerable = a.invulnerable;
    caster.playAnim(a.animation ?? 'dodge', restart: true);
    game.particles.emit(x: caster.position.x, y: caster.position.y, color: const Color(0xffd9c9a8), count: 8, speed: 80, life: 0.4, size: 5, gravity: -20);
  }

  void _meleeArc(Actor caster, AbilityDef a, Vector2 dir) {
    final half = a.arc * math.pi / 360;
    var hitAny = false;
    for (final target in game.opponentsOf(caster.faction)) {
      if (!target.alive) continue;
      final d = target.ground - caster.ground;
      final dist = d.length;
      if (dist > a.range + target.radius) continue;
      if (dist > 0.05) {
        final ang = math.acos((d.dot(dir) / dist).clamp(-1.0, 1.0));
        if (ang > half + 0.15) continue;
      }
      game.combat.hit(caster, target, a.damage, effects: a.effects, knockback: a.knockback, knockDir: dist > 0.05 ? d.normalized() : dir);
      hitAny = true;
    }
    final s = game.iso.toScreen(caster.ground.x + dir.x * a.range * 0.7, caster.ground.y + dir.y * a.range * 0.7);
    game.particles.emit(x: s.x, y: s.y - 20, color: const Color(0xffffffff), count: hitAny ? 8 : 4, speed: 150, life: 0.2, size: 3, shape: ParticleShape.spark);
    if (hitAny && caster is EnemyEntity && caster.def.isBoss) game.shake(4);
  }

  void _charge(Actor caster, AbilityDef a, Vector2 dir) {
    final hit = <Actor>{};
    caster.dashVelocity.setFrom(dir * a.speed);
    caster.dashTime = a.range / a.speed;
    caster.dashInvulnerable = false;
    caster.playAnim('charge', restart: true, speed: 1.4);
    if (caster is EnemyEntity) {
      caster.onDashStepHook = (made) {
        for (final target in game.opponentsOf(caster.faction)) {
          if (hit.contains(target) || !target.alive) continue;
          final reach = caster.radius + target.radius + 0.2;
          if (caster.ground.distanceToSquared(target.ground) < reach * reach) {
            hit.add(target);
            final side = Vector2(-dir.y, dir.x);
            final away = target.ground - caster.ground;
            final push = (dir + side * (away.dot(side) >= 0 ? 0.6 : -0.6)).normalized();
            game.combat.hit(caster, target, a.damage, knockback: a.knockback, knockDir: push);
            game.shake(6);
          }
        }
        if (made < 0.35 && a.wallStun > 0) {
          // Slammed into something solid: break window!
          caster.dashTime = 0;
          caster.statuses.stun = a.wallStun;
          caster.vulnerability = 1.5;
          caster.vulnerableTime = a.wallStun;
          caster.say('*BONK*', duration: 1.5);
          game.shake(9);
          game.floatText(caster, 'STUNNED! +50% DMG', const Color(0xffffe066), size: 22);
          game.particles.ring(caster.position.x, caster.position.y, const Color(0xffe8d6a8), size: 120);
        }
      };
      caster.onDashEndHook = () {
        caster.onDashStepHook = null;
        caster.playAnim('idle');
      };
    }
  }
}

/// Helpers to tweak status specs from powers without mutating content.
class StatusSpecOverride implements StatusSpec {
  StatusSpecOverride._(this.status, this.duration, this.amount);

  factory StatusSpecOverride.slow(StatusSpec base, double amount) => StatusSpecOverride._('slow', base.duration, amount);
  factory StatusSpecOverride.root(double duration) => StatusSpecOverride._('root', duration, 0);

  @override
  final String status;
  @override
  final double duration;
  @override
  final double amount;
}

/// Arcing seed for Vine Trap (pure visual).
class SeedFx extends Component {
  SeedFx(this.from, this.to) : super(priority: 6);

  final Vector2 from, to;
  double t = 0;
  static const duration = 0.25;

  @override
  void update(double dt) {
    t += dt;
    if (t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (t / duration).clamp(0.0, 1.0);
    final p = from + (to - from) * k;
    final arc = math.sin(k * math.pi) * 60;
    canvas.drawCircle(Offset(p.x, p.y - arc), 6, Paint()..color = const Color(0x8882f16d));
    canvas.drawCircle(Offset(p.x, p.y - arc), 3.5, Paint()..color = const Color(0xff4faf35));
  }
}
