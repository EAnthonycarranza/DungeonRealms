import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../dungeon_realms_game.dart';
import '../entities/actor.dart';
import '../fx/fx.dart';

/// A ground-targeted effect: traps, rains of arrows, slams, hexes.
///
/// Lifecycle: [delay] (telegraph or arming) -> trigger hit -> ticks for
/// [duration]. Root/stun effects apply once per target, slows refresh.
class AreaEffect extends Component with HasGameReference<DungeonRealmsGame> {
  AreaEffect({
    required this.owner,
    required this.ability,
    required this.center,
    required this.radius,
    required this.delay,
    required this.duration,
    required this.tickInterval,
    required this.damage,
    required this.tickDamage,
    required this.effects,
    required this.visual,
    this.knockback = 0,
    this.telegraphed = false,
  });

  final Actor owner;
  final AbilityDef? ability;
  final Vector2 center;
  final double radius;
  final double delay;
  final double duration;
  final double tickInterval;
  final double damage;
  final double tickDamage;
  final List<StatusSpec> effects;
  final String visual;
  final double knockback;
  final bool telegraphed;

  double t = 0;
  double _tick = 0;
  bool _triggered = false;
  final _onceApplied = <Actor>{};
  final _rng = math.Random();

  bool get armed => t >= delay;

  Iterable<Actor> _targetsInside() sync* {
    for (final a in game.opponentsOf(owner.faction)) {
      if (!a.alive) continue;
      final r = radius + a.radius * 0.6;
      if (a.ground.distanceToSquared(center) <= r * r) yield a;
    }
  }

  void _applyEffects(Actor target, {required bool first}) {
    for (final e in effects) {
      final once = e.status == 'root' || e.status == 'stun';
      if (once && !first) continue;
      target.statuses.apply(e);
      if (once && first) game.floatText(target, e.status == 'root' ? 'Rooted!' : 'Stunned!', const Color(0xff9bff6a), size: 17);
    }
  }

  void _trigger() {
    _triggered = true;
    final s = game.iso.toScreenV(center);
    switch (visual) {
      case 'slam':
      case 'rocks':
        game.shake(visual == 'rocks' ? 7 : 5);
        game.particles.ring(s.x, s.y, const Color(0xffe8d6a8), size: radius * 90);
        game.particles.emit(
          x: s.x,
          y: s.y,
          color: const Color(0xff9c8a6a),
          count: 18,
          speed: 220,
          life: 0.6,
          size: 5,
          shape: ParticleShape.square,
          upBias: 120,
        );
      case 'hex':
        game.particles.emit(x: s.x, y: s.y, color: const Color(0xff9bff6a), count: 16, speed: 180, life: 0.5, size: 4, upBias: 100);
        game.particles.ring(s.x, s.y, const Color(0xffb36bff), size: radius * 90);
      case 'vines':
      case 'flair_vines':
        game.particles.emit(x: s.x, y: s.y, color: const Color(0xff6fcf4a), count: 14, speed: 140, life: 0.5, size: 4, shape: ParticleShape.leaf, upBias: 80);
    }
    for (final target in _targetsInside()) {
      final first = _onceApplied.add(target);
      if (damage > 0) {
        final away = target.ground - center;
        game.combat.hit(
          owner,
          target,
          damage,
          knockback: knockback,
          knockDir: away.length2 > 1e-6 ? away.normalized() : null,
          chargeGain: ability?.chargeGain ?? 0,
          abilityId: ability?.id,
        );
      }
      _applyEffects(target, first: first);
    }
  }

  @override
  void update(double dt) {
    t += dt;
    if (!_triggered && armed) _trigger();
    if (_triggered && duration > 0) {
      _tick += dt;
      while (_tick >= tickInterval) {
        _tick -= tickInterval;
        for (final target in _targetsInside()) {
          final first = _onceApplied.add(target);
          if (tickDamage > 0) {
            game.combat.hit(owner, target, tickDamage, chargeGain: 0.5, tick: true, abilityId: ability?.id);
          }
          _applyEffects(target, first: first);
        }
        if (visual == 'arrow_rain') _rainBurst();
      }
    }
    if (t >= delay + math.max(duration, 0.35)) removeFromParent();
  }

  void _rainBurst() {
    for (var i = 0; i < 5; i++) {
      final a = _rng.nextDouble() * math.pi * 2, r = math.sqrt(_rng.nextDouble()) * radius;
      final p = game.iso.toScreen(center.x + math.cos(a) * r, center.y + math.sin(a) * r);
      game.spawnFallingArrow(p);
    }
  }

  Path _ellipse(double scale) {
    final s = game.iso.toScreenV(center);
    final rx = radius * scale * game.iso.halfW * math.sqrt2, ry = radius * scale * game.iso.halfH * math.sqrt2;
    return Path()..addOval(Rect.fromCenter(center: Offset(s.x, s.y), width: rx * 2, height: ry * 2));
  }

  @override
  void render(Canvas canvas) {
    final full = _ellipse(1);
    if (!armed) {
      final k = delay <= 0 ? 1.0 : (t / delay).clamp(0.0, 1.0);
      if (telegraphed) {
        canvas.drawPath(full, Paint()..color = const Color(0x44ff3b2d));
        canvas.drawPath(_ellipse(math.max(0.05, k)), Paint()..color = const Color(0x77ff5b2d));
        canvas.drawPath(
          full,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xddff5b4d),
        );
      } else {
        canvas.drawPath(_ellipse(k), Paint()..color = const Color(0x3382f16d));
      }
      return;
    }
    final life = duration <= 0 ? 0.35 : duration;
    final age = t - delay;
    final fade = (1 - math.max(0, age - life + 0.4) / 0.4).clamp(0.0, 1.0);
    switch (visual) {
      case 'vines':
      case 'flair_vines':
        canvas.drawPath(full, Paint()..color = Color.fromRGBO(80, 170, 60, 0.32 * fade));
        canvas.drawPath(
          full,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Color.fromRGBO(111, 207, 74, 0.9 * fade),
        );
        final s = game.iso.toScreenV(center);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = Color.fromRGBO(63, 154, 48, fade);
        for (var i = 0; i < 9; i++) {
          final a = i / 9 * math.pi * 2 + 0.3;
          final px = s.x + math.cos(a) * radius * 70, py = s.y + math.sin(a) * radius * 35;
          final grow = math.min(1.0, age * 5);
          final path = Path()
            ..moveTo(px, py)
            ..quadraticBezierTo(px + 10 * math.sin(game.time * 3 + i), py - 14 * grow, px + 3, py - 28 * grow);
          canvas.drawPath(path, paint);
        }
      case 'arrow_rain':
        canvas.drawPath(full, Paint()..color = Color.fromRGBO(30, 40, 70, 0.28 * fade));
        canvas.drawPath(
          full,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Color.fromRGBO(255, 233, 168, 0.8 * fade),
        );
      case 'hot_sauce':
        canvas.drawPath(full, Paint()..color = Color.fromRGBO(220, 50, 30, 0.45 * fade));
        canvas.drawPath(_ellipse(0.6), Paint()..color = Color.fromRGBO(255, 120, 40, 0.5 * fade));
      default:
        // Impacts: brief scorch.
        canvas.drawPath(full, Paint()..color = Color.fromRGBO(40, 30, 20, 0.35 * fade));
    }
  }
}
