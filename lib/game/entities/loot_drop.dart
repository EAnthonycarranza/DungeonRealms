import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../rules/loot.dart';
import 'entity.dart';

/// Something on the ground waiting to be picked up.
class LootDrop extends GameEntity {
  LootDrop(this.drop, Vector2 ground, this.velocity) : super(ground: ground, radius: 0.2) {
    boundsHalfWidth = 40;
    boundsHeight = drop.kind == DropKind.item ? 200 : 60;
    _vz = 260 + math.Random().nextDouble() * 120;
  }

  final Drop drop;
  final Vector2 velocity;
  double _vz = 0;
  double _age = 0;
  bool landed = false;
  bool collected = false;
  Image? icon;
  String? rarity;
  Color beamColor = const Color(0xffffffff);

  double get pickupRadius => switch (drop.kind) {
    DropKind.healthOrb => 1.0,
    DropKind.item => 1.0,
    _ => 1.6,
  };

  @override
  void update(double dt) {
    _age += dt;
    if (!landed) {
      ground.addScaled(velocity, dt);
      z += _vz * dt;
      _vz -= 900 * dt;
      if (z <= 0) {
        z = 0;
        landed = true;
        if (drop.kind == DropKind.item && (rarity == 'legendary' || rarity == 'epic')) {
          game.particles.ring(position.x, position.y, beamColor, size: 70);
        }
      }
    } else if (!collected) {
      final hero = game.hero;
      if (hero.alive) {
        final d = hero.ground.distanceTo(ground);
        // Gold and orbs get vacuumed toward the hero.
        if (drop.kind != DropKind.item && d < pickupRadius * 2.2) {
          ground.addScaled((hero.ground - ground).normalized(), math.min(d, 9 * dt));
        }
        if (d < pickupRadius * 0.55) game.collectDrop(this);
      }
    }
    if (drop.kind == DropKind.healthOrb && _age > game.data.healthOrb.lifetime) despawn();
    if (_age > 180) despawn();
    super.update(dt);
  }

  @override
  void renderGround(Canvas canvas) {
    if (drop.kind == DropKind.item) {
      final pulse = 0.5 + 0.5 * math.sin(_age * 3);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 46, height: 22), Paint()..color = beamColor.withValues(alpha: 0.25 + 0.2 * pulse));
    } else {
      canvas.drawOval(const Rect.fromLTWH(-8, -3, 16, 6), Paint()..color = const Color(0x33000000));
    }
  }

  @override
  void render(Canvas canvas) {
    final bob = landed ? math.sin(_age * 3) * 2.5 : 0.0;
    canvas.save();
    canvas.translate(0, -z - bob);
    switch (drop.kind) {
      case DropKind.item:
        if (landed) {
          final tall = rarity == 'legendary' ? 190.0 : (rarity == 'epic' ? 140.0 : 80.0);
          final beam = Rect.fromLTWH(-9, -tall, 18, tall);
          canvas.drawRect(
            beam,
            Paint()..shader = Gradient.linear(Offset(0, -tall), Offset.zero, [beamColor.withValues(alpha: 0), beamColor.withValues(alpha: 0.55)]),
          );
        }
        final img = icon;
        if (img != null) {
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            const Rect.fromLTWH(-17, -38, 34, 34),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
      case DropKind.gold:
        for (var i = 0; i < math.min(4, 1 + drop.amount ~/ 8); i++) {
          final o = Offset((i % 2) * 6.0 - 3, -6.0 - i * 3);
          canvas.drawOval(Rect.fromCenter(center: o + const Offset(0, 2), width: 14, height: 8), Paint()..color = const Color(0xffb07a12));
          canvas.drawOval(Rect.fromCenter(center: o, width: 14, height: 8), Paint()..color = const Color(0xffffc94f));
        }
      case DropKind.healthOrb:
        final pulse = 0.5 + 0.5 * math.sin(_age * 6);
        canvas.drawCircle(const Offset(0, -14), 14 + pulse * 3, Paint()..color = const Color(0x44ff4b4b));
        canvas.drawCircle(const Offset(0, -14), 8, Paint()..color = const Color(0xffff4b4b));
        canvas.drawCircle(const Offset(-2.5, -17), 3, Paint()..color = const Color(0xffffd0d0));
      default:
        final img = icon;
        if (img != null) {
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            const Rect.fromLTWH(-14, -30, 28, 28),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
    }
    canvas.restore();
  }
}
