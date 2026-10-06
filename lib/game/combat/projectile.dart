import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../entities/actor.dart';
import '../fx/fx.dart';
import '../entities/entity.dart';

/// Called when a projectile hits; return false to stop default handling.
typedef ProjectileHitHook = void Function(Projectile p, Actor target, int hitIndex);

/// A flying projectile (arrows, rocks, hex bolts). Moves in world space and
/// is drawn in depth order with the other entities.
class Projectile extends GameEntity {
  Projectile({
    required this.owner,
    required this.ability,
    required Vector2 start,
    required Vector2 direction,
    required this.speed,
    required this.range,
    required this.multiplier,
    required this.pierce,
    required this.sprite,
    required super.radius,
    this.effects = const [],
    this.knockback = 0,
    this.chargeGain = 0,
    this.onHitHook,
  }) : dir = direction.normalized(),
       super(ground: start.clone()) {
    z = 38;
    boundsHalfWidth = 40;
    boundsHeight = 60;
  }

  final Actor owner;
  final AbilityDef ability;
  final Vector2 dir;
  final double speed;
  final double range;
  final double multiplier;
  int pierce;
  final String sprite;
  final List<StatusSpec> effects;
  final double knockback;
  final double chargeGain;
  final ProjectileHitHook? onHitHook;
  final hit = <Actor>{};
  double traveled = 0;
  double _age = 0;
  bool _dying = false;

  @override
  void update(double dt) {
    _age += dt;
    if (_dying) {
      super.update(dt);
      return;
    }
    final step = speed * dt;
    ground.addScaled(dir, step);
    traveled += step;
    if (traveled >= range || ground.x < 0 || ground.y < 0 || ground.x > game.map.width || ground.y > game.map.height) {
      _finish(spark: false);
    } else {
      for (final target in game.opponentsOf(owner.faction)) {
        if (!target.alive || hit.contains(target) || target.isInvulnerable) continue;
        final reach = radius + target.radius;
        if (ground.distanceToSquared(target.ground) > reach * reach) continue;
        hit.add(target);
        game.combat.hit(owner, target, multiplier, effects: effects, knockback: knockback, knockDir: dir, chargeGain: chargeGain, abilityId: ability.id);
        onHitHook?.call(this, target, hit.length - 1);
        if (pierce <= 0) {
          _finish(spark: true);
          break;
        }
        pierce--;
      }
    }
    super.update(dt);
  }

  void _finish({required bool spark}) {
    if (_dying) return;
    _dying = true;
    if (spark) {
      final c = sprite == 'hex_bolt' ? const Color(0xff9bff6a) : (sprite == 'golden_arrow' ? const Color(0xffffe066) : const Color(0xfffff1c7));
      game.particles.emit(
        x: position.x,
        y: position.y - z,
        color: c,
        count: 6,
        speed: 120,
        life: 0.25,
        size: 3,
        shape: sprite == 'rock' ? ParticleShape.square : ParticleShape.spark,
      );
    }
    despawn();
  }

  @override
  void renderGround(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTWH(-9, -3, 18, 6), Paint()..color = const Color(0x33000000));
  }

  @override
  void render(Canvas canvas) {
    final s = game.iso.worldDirToScreen(dir.x, dir.y);
    final angle = math.atan2(s.y, s.x);
    canvas.save();
    canvas.translate(0, -z);
    switch (sprite) {
      case 'rock':
        final spin = _age * 12;
        canvas.rotate(spin);
        canvas.drawOval(const Rect.fromLTWH(-7, -6, 14, 12), Paint()..color = const Color(0xff2e2a24));
        canvas.drawOval(const Rect.fromLTWH(-5.5, -4.5, 11, 9), Paint()..color = const Color(0xff9c978c));
        canvas.drawCircle(const Offset(-2, -2), 2, Paint()..color = const Color(0xffcfc8bb));
      case 'hex_bolt':
        for (var i = 1; i <= 4; i++) {
          final back = Offset(-math.cos(angle) * i * 7, -math.sin(angle) * i * 7);
          canvas.drawCircle(back, 9.0 - i * 1.6, Paint()..color = Color.fromRGBO(155, 255, 106, 0.35 - i * 0.07));
        }
        canvas.drawCircle(Offset.zero, 11, Paint()..color = const Color(0x5582f16d));
        canvas.drawCircle(Offset.zero, 6.5, Paint()..color = const Color(0xff9bff6a));
        canvas.drawCircle(const Offset(-2, -2), 2.5, Paint()..color = const Color(0xffe8ffe0));
      default:
        canvas.rotate(angle);
        final golden = sprite == 'golden_arrow';
        if (golden) {
          canvas.drawLine(
            const Offset(-46, 0),
            const Offset(10, 0),
            Paint()
              ..color = const Color(0x66ffe066)
              ..strokeWidth = 10
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawLine(
          const Offset(-20, 0),
          const Offset(12, 0),
          Paint()
            ..color = const Color(0xff3a2412)
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(-20, 0),
          const Offset(12, 0),
          Paint()
            ..color = golden ? const Color(0xffffe9a8) : const Color(0xffd9b07a)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        final head = Path()
          ..moveTo(19, 0)
          ..lineTo(10, -4.5)
          ..lineTo(10, 4.5)
          ..close();
        canvas.drawPath(head, Paint()..color = golden ? const Color(0xffffd23f) : const Color(0xffd6dde4));
        canvas.drawPath(
          head,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xff2a2018),
        );
        final fl = Path()
          ..moveTo(-14, 0)
          ..lineTo(-21, -5)
          ..lineTo(-18, 0)
          ..lineTo(-21, 5)
          ..close();
        canvas.drawPath(fl, Paint()..color = golden ? const Color(0xffffc94f) : const Color(0xff6fcf4a));
    }
    canvas.restore();
  }
}
