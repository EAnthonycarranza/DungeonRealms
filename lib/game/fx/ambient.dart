import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';
import 'fx.dart';

/// Leaves drifting through the camera view (Goblinwood ambience).
class AmbientLeaves extends Component with HasGameReference<DungeonRealmsGame> {
  AmbientLeaves() : super(priority: 7);

  final _rng = math.Random();
  double _t = 0;
  static const _colors = [Color(0xcc8bcf4a), Color(0xccd9a13a), Color(0xccc0662a), Color(0xcc6fb042)];

  @override
  void update(double dt) {
    _t -= dt;
    if (_t > 0) return;
    _t = 0.35;
    final view = game.camera.visibleWorldRect;
    game.particles.emit(
      x: view.left + _rng.nextDouble() * view.width,
      y: view.top + _rng.nextDouble() * view.height * 0.4,
      color: _colors[_rng.nextInt(_colors.length)],
      count: 1,
      speed: 40,
      life: 5,
      size: 5,
      gravity: 14,
      drag: 0.2,
      shape: ParticleShape.leaf,
      angle: math.pi * 0.35,
      spread: 0.8,
    );
  }
}

/// One arrow from Arrow Storm, falling onto [target] (screen space).
class FallingArrowFx extends Component with HasGameReference<DungeonRealmsGame> {
  FallingArrowFx(this.target) : super(priority: 6);

  final Vector2 target;
  double t = 0;
  static const fall = 0.18;
  final _tilt = (math.Random().nextDouble() - 0.5) * 0.3;

  @override
  void update(double dt) {
    t += dt;
    if (t >= fall) {
      game.particles.emit(x: target.x, y: target.y, color: const Color(0xffd9c9a8), count: 3, speed: 60, life: 0.3, size: 3, upBias: 40);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = (t / fall).clamp(0.0, 1.0);
    final y = target.y - 260 * (1 - k);
    canvas.save();
    canvas.translate(target.x + 40 * (1 - k) * _tilt, y);
    canvas.rotate(math.pi / 2 + _tilt);
    canvas.drawLine(
      const Offset(-26, 0),
      const Offset(8, 0),
      Paint()
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff3a2412),
    );
    canvas.drawLine(
      const Offset(-26, 0),
      const Offset(8, 0),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xffffe9a8),
    );
    canvas.drawPath(
      Path()
        ..moveTo(14, 0)
        ..lineTo(6, -4)
        ..lineTo(6, 4)
        ..close(),
      Paint()..color = const Color(0xffd6dde4),
    );
    canvas.restore();
  }
}
