// Grizzlefang: a very large bear wearing stolen goblin armour.
//
// Quadruped rig drawn facing screen-right. "rear" lifts the front half of the
// body (roars and slams), "swipe" swings the near front paw.
import 'dart:math' as math;
import 'dart:ui';

import 'characters.dart';
import 'common.dart';
import 'rig_humanoid.dart' show AnimSpec;

class BearPose {
  double bodyY = 0;
  double pitch = 0; // + tips the front down
  double rear = 0; // 0..1 rearing up on hind legs
  double headTilt = 0;
  double headLow = 0;
  double mouth = 0; // 0..1
  double swipe = 0; // near front leg angle offset (radians)
  double slamReach = 0; // both front paws forward
  final legSwing = [0.0, 0.0, 0.0, 0.0]; // backFar, frontFar, backNear, frontNear
  final legLift = [0.0, 0.0, 0.0, 0.0];
  String face = 'angry';
  double collapse = 0; // death
  double rage = 0; // red tint/glow
}

final _fur = hex(0x7a4a2a);
final _furLight = hex(0xa8703f);
final _belly = hex(0xc49a6a);
final _snout = hex(0xd1ab80);
final _iron = hex(0x7d8590);

Offset _rot(Offset p, Offset pivot, double a) => rotateAround(p, pivot, a);

void drawBear(Canvas c, Offset feet, Object poseObj, bool back) {
  final p = poseObj as BearPose;
  c.save();
  c.translate(feet.dx, feet.dy);

  final hipPivot = const Offset(-62, -62);
  final bodyAngle = -p.rear * 0.95 + p.pitch;
  Offset body(Offset q) => _rot(q + Offset(0, p.bodyY + p.collapse * 34), hipPivot, bodyAngle);

  // Leg roots (in body space) and default paw positions (ground space).
  final roots = [const Offset(-48, -74), const Offset(40, -82), const Offset(-70, -64), const Offset(28, -74)];
  final paws = [const Offset(-44, 0), const Offset(52, 0), const Offset(-66, 0), const Offset(36, 0)];

  void leg(int i, {required bool near}) {
    final root = body(roots[i]);
    var paw = paws[i] + Offset(math.sin(p.legSwing[i]) * 30, -p.legLift[i]);
    final isFront = i == 1 || i == 3;
    if (isFront && p.rear > 0) {
      // Front paws follow the body up when rearing.
      final hang = root + Offset(14 + p.slamReach * 26, 52 - p.rear * 8);
      paw = Offset.lerp(paw, hang, math.min(1, p.rear * 1.4))!;
    }
    if (i == 3 && p.swipe != 0) {
      paw = root + polar(math.pi / 2 - p.swipe, 74);
    }
    if (p.collapse > 0) {
      paw = Offset.lerp(paw, root + Offset(isFront ? 40 : -30, 30), p.collapse)!;
    }
    final color = near ? _fur : shade(_fur, -0.18);
    final mid = Offset.lerp(root, paw, 0.5)! + Offset(isFront ? -8 : 10, 0);
    final path = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, paw.dx, paw.dy - 6);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 34
        ..color = outlineOf(color),
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 29
        ..color = color,
    );
    c.drawPath(
      path.shift(const Offset(-4, -2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8
        ..color = withAlpha(_furLight, 0.35),
    );
    // Paw + claws.
    inkedBall(c, ellipsePath(paw + const Offset(6, -4), 20, 11), shade(color, -0.05), outline: 2.4);
    for (var k = 0; k < 3; k++) {
      final base = paw + Offset(16 + k * 1.0, -9 + k * 5.0);
      inked(c, polygon([base, base + const Offset(10, 2), base + const Offset(0, 5)]), hex(0xf2e6cf), outline: 1.4);
    }
  }

  // --- far legs
  if (!back) {
    leg(0, near: false);
    leg(1, near: false);
  } else {
    leg(1, near: false);
    leg(3, near: false);
  }

  // --- head (in back view, behind the body)
  void head() {
    final neck = body(const Offset(70, -112));
    final h = neck + Offset(8 + p.headLow * 6, p.headLow * 34) + polar(-math.pi / 2 + p.headTilt, 4);
    final tilt = p.headTilt - bodyAngle * 0.4;
    c.save();
    c.translate(h.dx, h.dy);
    c.rotate(tilt);
    // Ears.
    for (final e in [const Offset(-22, -34), const Offset(14, -38)]) {
      inkedBall(c, circlePath(e, 13), _fur, outline: 2.4);
      c.drawCircle(e + const Offset(1, 2), 6, Paint()..color = withAlpha(hex(0xd98a7a), 0.7));
    }
    // Skull.
    final skull = smoothClosed([
      const Offset(-38, -4),
      const Offset(-26, -34),
      const Offset(6, -42),
      const Offset(34, -26),
      const Offset(44, 2),
      const Offset(30, 30),
      const Offset(-6, 36),
      const Offset(-34, 22),
    ], tension: 0.5);
    inkedBall(c, skull, _fur, outline: 3);
    if (!back) {
      // Snout.
      final snout = smoothClosed([const Offset(22, -6), const Offset(54, -8), const Offset(70, 6), const Offset(58, 24), const Offset(24, 22)], tension: 0.5);
      inkedBall(c, snout, _snout, outline: 2.6);
      inkedBall(c, ellipsePath(const Offset(64, 2), 9, 7), hex(0x2a1a10), outline: 1.6);
      // Mouth / teeth.
      if (p.mouth > 0.05) {
        final m = Path()
          ..moveTo(28, 16)
          ..quadraticBezierTo(46, 18 + p.mouth * 22, 64, 16)
          ..lineTo(60, 14)
          ..quadraticBezierTo(44, 10, 30, 13)
          ..close();
        inked(c, m, hex(0x7a1e24), outline: 2);
        for (var k = 0; k < 4; k++) {
          final x = 34.0 + k * 8;
          c.drawPath(polygon([Offset(x, 14), Offset(x + 3, 14 + 6 + p.mouth * 4), Offset(x + 6, 14)]), Paint()..color = hex(0xfff6e0));
        }
        c.drawOval(Rect.fromCenter(center: Offset(46, 20 + p.mouth * 14), width: 14, height: 6), Paint()..color = hex(0xd9606a));
      } else {
        strokeLine(c, const Offset(30, 16), const Offset(58, 18), hex(0x2a1a10), 2);
      }
      // Eyes.
      final glow = p.face == 'angry' ? hex(0xffd23f) : hex(0xffffff);
      for (final (e, r) in [(const Offset(8, -12), 6.5), (const Offset(28, -10), 5.0)]) {
        if (p.face == 'dead') {
          strokeLine(c, e + const Offset(-5, -5), e + const Offset(5, 5), hex(0x1a0f08), 2.6);
          strokeLine(c, e + const Offset(-5, 5), e + const Offset(5, -5), hex(0x1a0f08), 2.6);
        } else if (p.face == 'hurt') {
          strokeLine(c, e + const Offset(-6, -3), e + const Offset(5, 1), hex(0x1a0f08), 2.6);
        } else {
          if (p.rage > 0) {
            c.drawCircle(e, r * 2.2, Paint()..shader = Gradient.radial(e, r * 2.2, [withAlpha(hex(0xff5b2d), 0.6 * p.rage), withAlpha(hex(0xff5b2d), 0)]));
          }
          inkedBall(c, circlePath(e, r), glow, outline: 1.8);
          c.drawCircle(e + const Offset(1.5, 0.5), r * 0.45, Paint()..color = hex(0x1a0f08));
        }
      }
      // Angry brow + scar.
      strokeLine(c, const Offset(-2, -24), const Offset(16, -18), hex(0x3a2210), 4);
      strokeLine(c, const Offset(20, -20), const Offset(34, -20), hex(0x3a2210), 3.4);
      strokeLine(c, const Offset(2, -30), const Offset(12, 4), hex(0xe8c8a8), 2.4);
    } else {
      // Back of the head: a tuft of fur.
      for (var k = 0; k < 4; k++) {
        strokeLine(c, Offset(-18 + k * 9.0, -24), Offset(-22 + k * 9.0, -8), withAlpha(hex(0x4a2a14), 0.6), 2.4);
      }
    }
    // Stolen goblin helmet (dented, too small).
    final helm = Path()
      ..moveTo(-20, -34)
      ..quadraticBezierTo(-6, -58, 18, -40)
      ..lineTo(14, -32)
      ..quadraticBezierTo(-2, -40, -16, -28)
      ..close();
    inked(c, helm, _iron, outline: 2, light: 0.4);
    inked(c, polygon([const Offset(-2, -50), const Offset(2, -66), const Offset(6, -48)]), hex(0xf2e6cf), outline: 1.6);
    c.restore();
  }

  if (back) head();

  // --- body
  final bodyCenter = body(const Offset(-10, -92));
  final torso = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 168, height: 112));
  c.save();
  c.translate(bodyCenter.dx, bodyCenter.dy);
  c.rotate(bodyAngle);
  inkedBall(c, torso, _fur, outline: 3.2, highlight: const Offset(-0.2, -0.6));
  if (!back) {
    // Belly.
    final belly = Path()
      ..moveTo(-60, 24)
      ..quadraticBezierTo(-10, 62, 60, 30)
      ..quadraticBezierTo(20, 44, -60, 24)
      ..close();
    c.drawPath(belly, Paint()..color = withAlpha(_belly, 0.85));
  }
  // Hump.
  inkedBall(c, ellipsePath(const Offset(34, -38), 46, 30), _fur, outline: 3, highlight: const Offset(-0.3, -0.7));
  // Fur tufts along the back.
  for (var k = 0; k < 7; k++) {
    final x = -70.0 + k * 20;
    final y = -46 + (x * x) / 400 - (k == 5 ? 8 : 0);
    strokeLine(c, Offset(x, y), Offset(x - 6, y - 10), withAlpha(_furLight, 0.8), 3);
  }
  // Arrows stuck in his back (he hasn't noticed).
  for (final (pos, ang) in [(const Offset(-30, -48), -2.2), (const Offset(-8, -54), -1.9), (const Offset(-52, -36), -2.5)]) {
    final tip = pos + polar(ang, 34);
    strokeLine(c, pos, tip, hex(0x3a2412), 3.4);
    strokeLine(c, pos, tip, hex(0xd9b07a), 1.8);
    c.drawPath(polygon([tip, tip + polar(ang + 2.6, 8), tip + polar(ang - 2.6, 8)]), Paint()..color = hex(0xd8443a));
  }
  // Leather strap + spiked pauldron.
  final strap = Path()
    ..moveTo(10, -50)
    ..quadraticBezierTo(30, 0, 18, 52)
    ..lineTo(30, 52)
    ..quadraticBezierTo(42, 0, 22, -52)
    ..close();
  inked(c, strap, hex(0x5a3a1e), outline: 1.8);
  if (p.rage > 0) {
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 190, height: 130),
      Paint()
        ..color = withAlpha(hex(0xff3b2d), 0.18 * p.rage)
        ..blendMode = BlendMode.srcATop,
    );
  }
  c.restore();

  final pauldronAt = body(const Offset(30, -108));
  c.save();
  c.translate(pauldronAt.dx, pauldronAt.dy);
  c.rotate(bodyAngle);
  final plate = Path()
    ..moveTo(-34, 10)
    ..quadraticBezierTo(-30, -26, 6, -30)
    ..quadraticBezierTo(38, -26, 40, 8)
    ..quadraticBezierTo(4, 0, -34, 10)
    ..close();
  inked(c, plate, _iron, outline: 2.6, light: 0.4);
  for (var k = 0; k < 3; k++) {
    final base = Offset(-18.0 + k * 18, -24 + (k == 1 ? -4 : 0));
    inked(c, polygon([base + const Offset(-6, 2), base + const Offset(0, -18), base + const Offset(6, 2)]), hex(0xc9d1d9), outline: 1.8, light: 0.4);
  }
  c.restore();

  if (back) {
    // Stubby tail at the rear.
    inkedBall(c, circlePath(body(const Offset(-92, -96)), 12), _furLight, outline: 2.2);
  }

  // --- near legs and head (front view)
  if (!back) {
    leg(2, near: true);
    head();
    leg(3, near: true);
  } else {
    leg(0, near: true);
    leg(2, near: true);
  }
  c.restore();
}

double _w(double t, [double ph = 0]) => math.sin((t + ph) * math.pi * 2);

Map<String, AnimSpec<BearPose>> bearAnims() => {
  'idle': AnimSpec(
    6,
    6,
    true,
    (t, f) => BearPose()
      ..bodyY = _w(t) * 2
      ..headTilt = _w(t) * 0.04
      ..mouth = 0,
  ),
  'walk': AnimSpec(8, 9, true, (t, f) {
    final p = BearPose()..bodyY = _w(t * 2) * 2.5;
    const phase = [0.5, 0.75, 0.0, 0.25];
    for (var i = 0; i < 4; i++) {
      p.legSwing[i] = _w(t, phase[i]) * 0.38;
      p.legLift[i] = math.max(0, math.cos((t + phase[i]) * math.pi * 2)) * 10;
    }
    return p;
  }),
  'charge': AnimSpec(6, 14, true, (t, f) {
    final p = BearPose()
      ..pitch = 0.1
      ..headLow = 1
      ..bodyY = _w(t * 2) * 5
      ..mouth = 0.4;
    const phase = [0.5, 0.0, 0.55, 0.05];
    for (var i = 0; i < 4; i++) {
      p.legSwing[i] = _w(t, phase[i]) * 0.65;
      p.legLift[i] = math.max(0, math.cos((t + phase[i]) * math.pi * 2)) * 16;
    }
    return p;
  }),
  'swipe': AnimSpec(7, 14, false, (t, f) {
    const swipe = [0.2, -0.6, -1.1, -0.4, 1.3, 1.5, 0.6];
    const rear = [0.05, 0.2, 0.3, 0.25, 0.1, 0.05, 0.0];
    return BearPose()
      ..rear = rear[f]
      ..swipe = swipe[f]
      ..mouth = f >= 3 && f <= 5 ? 0.7 : 0.2
      ..headTilt = f >= 4 ? 0.1 : -0.1;
  }, events: {'hit': 4}),
  'roar': AnimSpec(6, 10, false, (t, f) {
    const rear = [0.15, 0.45, 0.6, 0.6, 0.6, 0.3];
    const mouth = [0.2, 0.6, 1.0, 1.0, 1.0, 0.4];
    return BearPose()
      ..rear = rear[f]
      ..mouth = mouth[f]
      ..headTilt = -0.35 * rear[f]
      ..rage = f >= 2 && f <= 4 ? 1 : 0;
  }, events: {'roar': 2}),
  'slam': AnimSpec(8, 12, false, (t, f) {
    const rear = [0.2, 0.5, 0.78, 0.88, 0.25, 0.0, 0.0, 0.0];
    const pitch = [0.0, 0.0, 0.0, 0.0, 0.12, 0.16, 0.08, 0.0];
    return BearPose()
      ..rear = rear[f]
      ..pitch = pitch[f]
      ..slamReach = f >= 4 && f <= 6 ? 1 : 0.3
      ..mouth = f >= 2 && f <= 5 ? 0.9 : 0.3
      ..headTilt = f <= 3 ? -0.25 : 0.15;
  }, events: {'hit': 5}),
  'hit': AnimSpec(
    3,
    12,
    false,
    (t, f) => BearPose()
      ..pitch = -0.08 * (1 - f / 2)
      ..face = 'hurt'
      ..mouth = 0.5,
  ),
  'death': AnimSpec(8, 8, false, (t, f) {
    final e = math.min(1.0, f / 6);
    return BearPose()
      ..collapse = e
      ..pitch = 0.1 * e
      ..face = f >= 4 ? 'dead' : 'hurt'
      ..mouth = 0.6;
  }),
};

CharacterSpec grizzlefangSpec() {
  final spec = CharacterSpec(id: 'grizzlefang', look: null, anims: bearAnims(), frameSize: 340, anchor: const Offset(148, 314), pixelRatio: 1.0);
  spec.customDraw = drawBear;
  return spec;
}
