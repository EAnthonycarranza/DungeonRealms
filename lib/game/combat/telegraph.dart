import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';

/// Ground warning shape for enemy attacks ("Readable Bosses").
///
/// The outline appears instantly; the fill grows until the attack lands.
class Telegraph extends Component with HasGameReference<DungeonRealmsGame> {
  Telegraph.cone({required this.origin, required this.dir, required this.range, required double arcDegrees, required this.duration})
    : shape = 'cone',
      arc = arcDegrees * math.pi / 180,
      width = 0;

  Telegraph.circle({required this.origin, required this.range, required this.duration}) : shape = 'circle', dir = Vector2(1, 0), arc = 0, width = 0;

  Telegraph.line({required this.origin, required this.dir, required this.range, required this.width, required this.duration}) : shape = 'line', arc = 0;

  final String shape;
  final Vector2 origin;
  final Vector2 dir;
  final double range;
  final double arc;
  final double width;
  final double duration;
  double t = 0;

  static final _fill = Paint()..color = const Color(0x55ff3b2d);
  static final _core = Paint()..color = const Color(0x88ff5b2d);
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xddff5b4d);

  @override
  void update(double dt) {
    t += dt;
    if (t >= duration) removeFromParent();
  }

  /// World-space polygon outline of the shape scaled by [k] (0..1).
  Path _path(double k) {
    final iso = game.iso;
    final path = Path();
    Offset s(double wx, double wy) {
      final v = iso.toScreen(wx, wy);
      return Offset(v.x, v.y);
    }

    switch (shape) {
      case 'circle':
        const n = 36;
        for (var i = 0; i <= n; i++) {
          final a = i / n * math.pi * 2;
          final p = s(origin.x + math.cos(a) * range * k, origin.y + math.sin(a) * range * k);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
      case 'cone':
        final base = math.atan2(dir.y, dir.x);
        final o = s(origin.x, origin.y);
        path.moveTo(o.dx, o.dy);
        const n = 20;
        for (var i = 0; i <= n; i++) {
          final a = base - arc / 2 + arc * i / n;
          final p = s(origin.x + math.cos(a) * range * k, origin.y + math.sin(a) * range * k);
          path.lineTo(p.dx, p.dy);
        }
      default:
        final n = Vector2(-dir.y, dir.x) * (width / 2);
        final end = origin + dir * (range * k);
        for (final (i, p) in [origin + n, end + n, end - n, origin - n].indexed) {
          final q = s(p.x, p.y);
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
    }
    return path..close();
  }

  @override
  void render(Canvas canvas) {
    final k = (t / duration).clamp(0.0, 1.0);
    final outline = _path(1);
    canvas.drawPath(outline, _fill);
    canvas.drawPath(_path(shape == 'line' ? k : math.max(0.05, k)), _core);
    canvas.drawPath(outline, _edge);
  }
}
