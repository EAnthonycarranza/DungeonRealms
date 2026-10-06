import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../content/ability_defs.dart';
import '../dungeon_realms_game.dart';

/// Max drag distance (screen px) of a skill button that maps to full range.
const aimDragRadius = 90.0;

/// Converts a skill-button drag into a world aim vector whose length is the
/// fraction of the ability's range (used for ground-targeted skills).
Vector2 dragToWorldAim(DungeonRealmsGame game, Vector2 drag) {
  final dir = game.iso.screenDirToWorld(drag.x, drag.y);
  final fraction = (drag.length / aimDragRadius).clamp(0.0, 1.0);
  return dir..scale(math.max(0.08, fraction));
}

/// Draws the drag-to-aim preview on the ground while a touch skill button
/// is held and dragged.
class AimIndicator extends Component with HasGameReference<DungeonRealmsGame> {
  AimIndicator() : super(priority: 5);

  static final _fill = Paint()..color = const Color(0x334fd4ff);
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xcc4fd4ff);

  @override
  void render(Canvas canvas) {
    final slot = game.input.aiming;
    if (slot == null) return;
    final a = game.hero.abilityFor(slot);
    if (a == null || game.input.aimDrag.length < 12) return;
    final aim = dragToWorldAim(game, game.input.aimDrag);
    final dir = aim.normalized();
    final origin = game.hero.ground;
    Offset s(Vector2 w) {
      final v = game.iso.toScreen(w.x, w.y);
      return Offset(v.x, v.y);
    }

    final path = Path();
    switch (a.aim) {
      case AimMode.ground:
        final center = origin + dir * (aim.length * a.range);
        const n = 32;
        final r = math.max(0.6, a.radius);
        for (var i = 0; i <= n; i++) {
          final ang = i / n * math.pi * 2;
          final p = s(center + Vector2(math.cos(ang), math.sin(ang)) * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        // Range ring around the hero.
        final ring = Path();
        for (var i = 0; i <= 48; i++) {
          final ang = i / 48 * math.pi * 2;
          final p = s(origin + Vector2(math.cos(ang), math.sin(ang)) * a.range);
          i == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0x554fd4ff),
        );
      case AimMode.cone:
        final base = math.atan2(dir.y, dir.x);
        final half = (a.spread > 0 ? a.spread : 50) * math.pi / 360;
        final o = s(origin);
        path.moveTo(o.dx, o.dy);
        for (var i = 0; i <= 16; i++) {
          final ang = base - half + half * 2 * i / 16;
          final p = s(origin + Vector2(math.cos(ang), math.sin(ang)) * a.range);
          path.lineTo(p.dx, p.dy);
        }
      default:
        final width = a.aim == AimMode.line ? 0.55 : 0.3;
        final n = Vector2(-dir.y, dir.x) * width;
        final end = origin + dir * a.range;
        for (final (i, p) in [origin + n, end + n, end - n, origin - n].indexed) {
          final q = s(p);
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
    }
    path.close();
    canvas.drawPath(path, _fill);
    canvas.drawPath(path, _edge);
  }
}
