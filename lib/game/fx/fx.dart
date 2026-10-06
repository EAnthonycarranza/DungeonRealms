import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Rising combat text (damage numbers, "+XP", "Rooted!").
class FloatingText extends Component {
  FloatingText(
    String text, {
    required Vector2 at,
    Color color = const Color(0xffffffff),
    double size = 22,
    this.life = 0.9,
    Vector2? velocity,
    bool bold = true,
  }) : position = at.clone(),
       velocity = velocity ?? Vector2(0, -55) {
    final style = TextStyle(fontFamily: 'LilitaOne', fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    _fill = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    _stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xff1a1208),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  final Vector2 position;
  final Vector2 velocity;
  final double life;
  double _t = 0;
  late final TextPainter _fill, _stroke;

  @override
  void update(double dt) {
    _t += dt;
    position.addScaled(velocity, dt);
    velocity.y += 60 * dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final pop = _t < 0.12 ? 0.6 + _t / 0.12 * 0.55 : 1.15 - math.min(0.15, (_t - 0.12) * 0.6);
    final alpha = _t > life * 0.65 ? (1 - (_t - life * 0.65) / (life * 0.35)).clamp(0.0, 1.0) : 1.0;
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.scale(pop);
    final offset = Offset(-_fill.width / 2, -_fill.height / 2);
    if (alpha < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    _stroke.paint(canvas, offset);
    _fill.paint(canvas, offset);
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }
}

enum ParticleShape { dot, spark, ring, leaf, square }

class _Particle {
  double x = 0, y = 0, vx = 0, vy = 0, gravity = 0, life = 1, t = 0, size = 4, spin = 0, angle = 0, drag = 0;
  Color color = const Color(0xffffffff);
  ParticleShape shape = ParticleShape.dot;
  bool fade = true;
}

/// One component that simulates and draws all short-lived particles.
class ParticleSystem extends Component {
  ParticleSystem() : super(priority: 5);

  final _alive = <_Particle>[];
  final _pool = <_Particle>[];
  final _rng = math.Random();
  final _paint = Paint()..isAntiAlias = true;

  int get count => _alive.length;

  void emit({
    required double x,
    required double y,
    required Color color,
    int count = 8,
    double speed = 120,
    double speedJitter = 0.6,
    double life = 0.5,
    double size = 4,
    double gravity = 260,
    double drag = 1.5,
    ParticleShape shape = ParticleShape.dot,
    double angle = -math.pi / 2,
    double spread = math.pi * 2,
    double upBias = 0,
  }) {
    for (var i = 0; i < count; i++) {
      if (_alive.length > 1400) return;
      final p = _pool.isNotEmpty ? _pool.removeLast() : _Particle();
      final a = angle + (_rng.nextDouble() - 0.5) * spread;
      final s = speed * (1 - speedJitter / 2 + _rng.nextDouble() * speedJitter);
      p
        ..x = x
        ..y = y
        ..vx = math.cos(a) * s
        ..vy = math.sin(a) * s * 0.7 - upBias
        ..gravity = gravity
        ..drag = drag
        ..life = life * (0.7 + _rng.nextDouble() * 0.6)
        ..t = 0
        ..size = size * (0.7 + _rng.nextDouble() * 0.6)
        ..color = color
        ..shape = shape
        ..angle = _rng.nextDouble() * math.pi * 2
        ..spin = (_rng.nextDouble() - 0.5) * 8
        ..fade = true;
      _alive.add(p);
    }
  }

  /// Expanding ring (level up, slam impacts).
  void ring(double x, double y, Color color, {double size = 60, double life = 0.45}) {
    final p = _pool.isNotEmpty ? _pool.removeLast() : _Particle();
    p
      ..x = x
      ..y = y
      ..vx = 0
      ..vy = 0
      ..gravity = 0
      ..drag = 0
      ..life = life
      ..t = 0
      ..size = size
      ..color = color
      ..shape = ParticleShape.ring;
    _alive.add(p);
  }

  @override
  void update(double dt) {
    for (var i = _alive.length - 1; i >= 0; i--) {
      final p = _alive[i];
      p.t += dt;
      if (p.t >= p.life) {
        _alive.removeAt(i);
        _pool.add(p);
        continue;
      }
      final k = math.max(0.0, 1 - p.drag * dt);
      p.vx *= k;
      p.vy = p.vy * k + p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.angle += p.spin * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final p in _alive) {
      final f = p.t / p.life;
      final a = p.fade ? (1 - f) : 1.0;
      _paint
        ..color = p.color.withValues(alpha: p.color.a * a)
        ..style = PaintingStyle.fill
        ..strokeWidth = 1;
      switch (p.shape) {
        case ParticleShape.dot:
          canvas.drawCircle(Offset(p.x, p.y), p.size * (1 - f * 0.5), _paint);
        case ParticleShape.square:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size), _paint);
          canvas.restore();
        case ParticleShape.spark:
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.size * 0.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(p.x, p.y), Offset(p.x - p.vx * 0.04, p.y - p.vy * 0.04), _paint);
        case ParticleShape.ring:
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - f) + 1;
          canvas.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: p.size * 2 * (0.3 + f), height: p.size * (0.3 + f)), _paint);
        case ParticleShape.leaf:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size), _paint);
          canvas.restore();
      }
    }
  }
}

/// Draws a cartoon speech bubble with [text] centred above (0, [y]).
void drawSpeechBubble(Canvas canvas, String text, double y, {double alpha = 1, Color color = const Color(0xfffff6e0)}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xff2a1d14)),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: 210);
  final w = tp.width + 20, h = tp.height + 12;
  final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, y - h / 2), width: w, height: h), const Radius.circular(12));
  canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
  final tail = Path()
    ..moveTo(-8, y - 2)
    ..lineTo(0, y + 10)
    ..lineTo(8, y - 2)
    ..close();
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xff2a1d14);
  canvas.drawRRect(rect, outline);
  canvas.drawPath(tail, outline);
  canvas.drawRRect(rect, Paint()..color = color);
  canvas.drawPath(tail, Paint()..color = color);
  tp.paint(canvas, Offset(-tp.width / 2, y - h + 6));
  canvas.restore();
}
