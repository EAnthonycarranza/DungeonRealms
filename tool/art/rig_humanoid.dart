// A small 2D "paper doll" rig for chibi humanoids (heroes, goblins, NPCs).
//
// Characters are drawn facing screen-right in two facings:
//   front = 3/4 view facing down-right, back = 3/4 view facing up-right.
// The engine mirrors frames for the left-facing directions.
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';

class HumanoidLook {
  HumanoidLook({
    this.headR = 17,
    this.torsoH = 26,
    this.torsoW = 22,
    this.hipW = 18,
    this.legLen = 30,
    this.armLen = 23,
    this.limbW = 8,
    required this.skin,
    required this.hair,
    required this.tunic,
    this.tunicTrim,
    required this.pants,
    required this.boots,
    this.belt,
    this.gloves,
    this.cloak,
    this.cloakTrim,
    this.eyeColor = const Color(0xff2b6b3a),
    this.hairStyle = 'short',
    this.ears = 'human',
    this.headgear = 'none',
    this.headgearColor,
    this.weapon = 'none',
    this.back = 'none',
    this.nose = 'small',
    this.beard = 'none',
    this.fangs = false,
    this.robe = false,
    this.hunch = 0,
    this.bulk = 1,
  });

  final double headR, torsoH, torsoW, hipW, legLen, armLen, limbW;
  final Color skin, hair, tunic, pants, boots;
  final Color? tunicTrim, belt, gloves, cloak, cloakTrim, headgearColor;
  final Color eyeColor;
  final String hairStyle; // short, long_wavy, wild, bun, braids, none, mohawk, gray_bun
  final String ears; // human, elf, goblin
  final String headgear; // none, hood_down, helmet, bandana, skull_mask, horned_helmet, feathers, leaf_crown, kerchief
  final String weapon; // bow, club, sling, staff, cleaver, spear, hammer, basket, none
  final String back; // quiver, backpack, none
  final String nose; // small, goblin, round
  final String beard; // none, mustache, braided
  final bool fangs;
  final bool robe;
  final double hunch;
  final double bulk;
}

class Pose {
  double bodyY = 0; // extra vertical body offset (px, + down)
  double lean = 0; // torso rotation, + leans forward (right)
  double headTilt = 0;
  double legF = 0, legB = 0; // hip angles, + swings forward
  double kneeF = 0, kneeB = 0; // knee bend (+ bends backward)
  double armF = 0.12, armB = -0.12; // shoulder angles, 0 = hanging, + forward/up
  double elbowF = 0.25, elbowB = 0.25; // elbow bend (+ bends forward)
  Offset? handF, handB; // optional IK targets relative to the shoulder
  double squash = 1; // vertical scale
  double rotation = 0; // whole-body rotation around the body centre
  double lift = 0; // jump offset (px, negative = up)
  double draw = 0; // bow draw / weapon charge 0..1
  double aim = 0; // aim angle (radians, 0 = forward, negative = up)
  double swing = 0; // melee weapon angle offset
  String face = 'normal'; // normal | angry | hurt | dead | focus | happy
  double cloakSway = 0;
  double glow = 0; // casting glow on hands 0..1
  Color glowColor = const Color(0xff9bff6a);
  bool arrowNocked = false;
  double fade = 1;
  bool groundFeet = true;
  // Planted mode: feet stay at fixed ground positions and the hip moves
  // (knees solved with IK). Used for idles, attacks and casts.
  bool planted = false;
  double footFx = -4, footBx = 7;
  double crouch = 0;
  // When true the far hand grabs the bow string (shooting poses).
  bool farHandOnString = false;
}

/// One animation: [frames] poses sampled from [pose] and played at [fps].
class AnimSpec<P> {
  const AnimSpec(this.frames, this.fps, this.loop, this.pose, {this.events = const {}});
  final int frames;
  final double fps;
  final bool loop;
  final P Function(double t, int frame) pose;
  final Map<String, int> events;
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

/// Direction for a limb angle measured from straight down, + toward +x.
Offset _dir(double angle) => Offset(math.sin(angle), math.cos(angle));

/// Two-bone IK: returns the elbow position for a limb from [a] reaching [t].
Offset _ik(Offset a, Offset t, double l1, double l2, {bool bendDown = true}) {
  var d = t - a;
  var dist = d.distance;
  final maxReach = l1 + l2 - 0.01;
  if (dist > maxReach) {
    d = d / dist * maxReach;
    dist = maxReach;
  }
  if (dist < 0.01) return a + Offset(0, l1);
  final cosA = ((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)).clamp(-1.0, 1.0);
  final angA = math.acos(cosA);
  final base = math.atan2(d.dy, d.dx);
  final ang = base + (bendDown ? angA : -angA);
  return a + Offset(math.cos(ang), math.sin(ang)) * l1;
}

void _limb(Canvas c, Offset a, Offset b, Offset e, double w, Color color, {double outline = 2}) {
  final o = outlineOf(color);
  final paintO = Paint()
    ..color = o
    ..strokeWidth = w + outline * 2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(e.dx, e.dy);
  c.drawPath(path, paintO);
  c.drawPath(
    path,
    Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round,
  );
  // Soft highlight along the limb.
  c.drawPath(
    path.shift(const Offset(-1, -1)),
    Paint()
      ..color = withAlpha(shade(color, 0.3), 0.35)
      ..strokeWidth = w * 0.35
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
}

// ---------------------------------------------------------------------------
// Main draw
// ---------------------------------------------------------------------------

class _Skeleton {
  late Offset hip, shoulder, head;
  late Offset hipF, hipB, kneeF, kneeB, footF, footB;
  late Offset shF, shB, elF, elB, handF, handB;
}

_Skeleton _solve(HumanoidLook k, Pose p) {
  final s = _Skeleton();
  final thigh = k.legLen * 0.5, shin = k.legLen * 0.5;
  final upper = k.armLen * 0.5, lower = k.armLen * 0.5;

  // Legs first (relative to hip at origin), then shift so the lowest foot
  // touches the ground.
  Offset legEnd(double hipAngle, double knee, Offset h, void Function(Offset knee) setKnee) {
    final kn = h + _dir(hipAngle) * thigh;
    setKnee(kn);
    return kn + _dir(hipAngle - knee) * shin;
  }

  if (p.planted) {
    final hip0 = Offset(0, -k.legLen + 1.5 + p.crouch + p.bodyY);
    s.hip = hip0;
    s.hipF = hip0 + const Offset(-2, 0);
    s.hipB = hip0 + const Offset(3, 0);
    s.footF = Offset(p.footFx, 0);
    s.footB = Offset(p.footBx, 0);
    s.kneeF = _ik(s.hipF, s.footF, thigh, shin, bendDown: false);
    s.kneeB = _ik(s.hipB, s.footB, thigh, shin, bendDown: false);
  } else {
    final hip0 = Offset(0, -k.legLen);
    late Offset kf, kb;
    final ff = legEnd(p.legF, p.kneeF, hip0 + const Offset(-2, 0), (v) => kf = v);
    final fb = legEnd(p.legB, p.kneeB, hip0 + const Offset(3, 0), (v) => kb = v);
    var drop = 0.0;
    if (p.groundFeet) {
      final lowest = math.max(ff.dy, fb.dy);
      drop = -lowest; // brings the lowest foot to y = 0
    }
    final shift = Offset(0, drop + p.bodyY);
    s.hip = hip0 + shift;
    s.hipF = hip0 + const Offset(-2, 0) + shift;
    s.hipB = hip0 + const Offset(3, 0) + shift;
    s.kneeF = kf + shift;
    s.kneeB = kb + shift;
    s.footF = ff + shift;
    s.footB = fb + shift;
  }

  // Torso.
  final lean = p.lean + k.hunch;
  s.shoulder = s.hip + Offset(math.sin(lean), -math.cos(lean)) * k.torsoH;
  final headLean = lean + p.headTilt;
  s.head = s.shoulder + Offset(math.sin(headLean), -math.cos(headLean)) * (k.headR * 0.82) + const Offset(2, 0);

  // Arms.
  s.shF = s.shoulder + Offset(-k.torsoW * 0.18, 3);
  s.shB = s.shoulder + Offset(k.torsoW * 0.22, 2);
  if (p.handF != null) {
    s.handF = s.shF + p.handF!;
    s.elF = _ik(s.shF, s.handF, upper, lower);
  } else {
    s.elF = s.shF + _dir(p.armF) * upper;
    s.handF = s.elF + _dir(p.armF + p.elbowF) * lower;
  }
  if (p.farHandOnString) {
    final aimDir = Offset(math.cos(p.aim), math.sin(p.aim));
    s.handB = s.handF - aimDir * (6 + p.draw * 22);
    s.elB = _ik(s.shB, s.handB, upper, lower);
  } else if (p.handB != null) {
    s.handB = s.shB + p.handB!;
    s.elB = _ik(s.shB, s.handB, upper, lower);
  } else {
    s.elB = s.shB + _dir(p.armB) * upper;
    s.handB = s.elB + _dir(p.armB + p.elbowB) * lower;
  }
  return s;
}

void drawHumanoid(Canvas c, Offset feet, HumanoidLook k, Pose p, {required bool back}) {
  c.save();
  c.translate(feet.dx, feet.dy + p.lift);
  if (p.squash != 1) c.scale(1 / math.sqrt(p.squash), p.squash);
  if (p.rotation != 0) {
    final pivot = Offset(0, -k.legLen - k.torsoH * 0.4);
    c.translate(pivot.dx, pivot.dy);
    c.rotate(p.rotation);
    c.translate(-pivot.dx, -pivot.dy);
  }
  if (p.fade < 1) {
    c.saveLayer(null, Paint()..color = withAlpha(const Color(0xffffffff), p.fade));
  }
  final s = _solve(k, p);

  if (!back) {
    _drawCloakBack(c, k, p, s);
    if (k.back == 'quiver') _drawQuiver(c, k, s, front: true);
    if (k.back == 'backpack') _drawBackpack(c, k, s, front: true);
    _drawArm(c, k, p, s, near: false);
    _drawLeg(c, k, s.hipB, s.kneeB, s.footB, near: false);
    _drawLeg(c, k, s.hipF, s.kneeF, s.footF, near: true);
    _drawTorso(c, k, p, s, back: false);
    _drawHead(c, k, p, s, back: false);
    _drawArm(c, k, p, s, near: true);
  } else {
    _drawArm(c, k, p, s, near: false);
    _drawLeg(c, k, s.hipB, s.kneeB, s.footB, near: false);
    _drawLeg(c, k, s.hipF, s.kneeF, s.footF, near: true);
    _drawTorso(c, k, p, s, back: true);
    if (k.back == 'quiver') _drawQuiver(c, k, s, front: false);
    _drawCloakOver(c, k, p, s);
    if (k.back == 'backpack') _drawBackpack(c, k, s, front: false);
    _drawHead(c, k, p, s, back: true);
    _drawArm(c, k, p, s, near: true);
  }
  if (p.fade < 1) c.restore();
  c.restore();
}

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------

void _drawLeg(Canvas c, HumanoidLook k, Offset hip, Offset knee, Offset foot, {required bool near}) {
  final color = near ? k.pants : shade(k.pants, -0.12);
  _limb(c, hip, knee, foot, k.limbW * k.bulk, color);
  // Boot: rounded shoe pointing forward.
  final boot = near ? k.boots : shade(k.boots, -0.12);
  final bootPath = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(foot.dx - k.limbW * 0.6, foot.dy - k.limbW * 0.9, k.limbW * 1.7 * k.bulk, k.limbW * 1.05),
        Radius.circular(k.limbW * 0.5),
      ),
    );
  inked(c, bootPath, boot, outline: 2);
  // Boot cuff.
  inked(c, roundRectPath(Rect.fromCenter(center: foot + Offset(0, -k.limbW * 1.0), width: k.limbW * 1.3, height: 4), 2), shade(boot, 0.15), outline: 1.6);
}

void _drawArm(Canvas c, HumanoidLook k, Pose p, _Skeleton s, {required bool near}) {
  final sh = near ? s.shF : s.shB;
  final el = near ? s.elF : s.elB;
  final hand = near ? s.handF : s.handB;
  final sleeve = near ? k.tunic : shade(k.tunic, -0.14);

  // Weapon held behind the arm when the weapon is in the far hand.
  if (!near) _drawFarHandItem(c, k, p, s);

  _limb(c, sh, el, hand, k.limbW * 0.95 * k.bulk, sleeve);
  final handColor = k.gloves ?? k.skin;
  if (p.glow > 0) {
    c.drawCircle(
      hand,
      14 * p.glow + 4,
      Paint()..shader = Gradient.radial(hand, 14 * p.glow + 4, [withAlpha(p.glowColor, 0.85 * p.glow), withAlpha(p.glowColor, 0)]),
    );
  }
  inkedBall(c, circlePath(hand, k.limbW * 0.62 * k.bulk), near ? handColor : shade(handColor, -0.1), outline: 1.8);

  if (near) _drawNearHandItem(c, k, p, s);
}

void _drawTorso(Canvas c, HumanoidLook k, Pose p, _Skeleton s, {required bool back}) {
  final lean = p.lean + k.hunch;
  c.save();
  c.translate(s.hip.dx, s.hip.dy);
  c.rotate(lean);
  final w = k.torsoW * k.bulk, hw = k.hipW * k.bulk, h = k.torsoH;
  final bottomFlare = k.robe ? 1.35 : 1.0;
  final bottomY = k.robe ? 10.0 : 4.0;
  final body = Path()
    ..moveTo(-w / 2, -h + 4)
    ..quadraticBezierTo(-w / 2 - 2, -h * 0.4, -hw / 2 * bottomFlare, bottomY)
    ..quadraticBezierTo(0, bottomY + 4, hw / 2 * bottomFlare, bottomY)
    ..quadraticBezierTo(w / 2 + 2, -h * 0.4, w / 2, -h + 4)
    ..quadraticBezierTo(0, -h - 3, -w / 2, -h + 4)
    ..close();
  inked(c, body, back ? shade(k.tunic, -0.06) : k.tunic, outline: 2.4);
  if (k.tunicTrim != null) {
    // Hem trim.
    final hem = Path()
      ..moveTo(-hw / 2 * bottomFlare, bottomY - 4)
      ..quadraticBezierTo(0, bottomY, hw / 2 * bottomFlare, bottomY - 4)
      ..lineTo(hw / 2 * bottomFlare, bottomY)
      ..quadraticBezierTo(0, bottomY + 4, -hw / 2 * bottomFlare, bottomY)
      ..close();
    c.drawPath(hem, Paint()..color = k.tunicTrim!);
    if (!back) {
      // Collar V.
      final v = Path()
        ..moveTo(-5, -h + 2)
        ..lineTo(1, -h + 11)
        ..lineTo(6, -h + 2);
      c.drawPath(
        v,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = k.tunicTrim!,
      );
    }
  }
  if (k.belt != null) {
    final beltRect = Rect.fromCenter(center: Offset(0, -h * 0.28), width: w * 1.02, height: 5);
    inked(c, roundRectPath(beltRect, 2), k.belt!, outline: 1.6, gradient: false);
    if (!back) {
      inked(c, roundRectPath(Rect.fromCenter(center: Offset(w * 0.15, -h * 0.28), width: 6, height: 6), 1.5), hex(0xffd36b), outline: 1.2);
    }
  }
  if (k.beard == 'braided' && !back) {
    // Big dwarven beard drapes over the chest (drawn in head pass too).
  }
  c.restore();
}

void _drawCloakBack(Canvas c, HumanoidLook k, Pose p, _Skeleton s) {
  if (k.cloak == null) return;
  final sway = p.cloakSway;
  final top = s.shoulder + const Offset(-6, 2);
  final path = Path()
    ..moveTo(top.dx + 6, top.dy - 2)
    ..quadraticBezierTo(top.dx - 14 - sway * 6, top.dy + 18, s.hip.dx - 16 - sway * 10, s.hip.dy + 18)
    ..lineTo(s.hip.dx - 6 - sway * 8, s.hip.dy + 14)
    ..lineTo(s.hip.dx - 2 - sway * 6, s.hip.dy + 20)
    ..quadraticBezierTo(s.hip.dx + 2, s.hip.dy, top.dx + 10, top.dy + 4)
    ..close();
  inked(c, path, shade(k.cloak!, -0.12), outline: 2.2);
}

void _drawCloakOver(Canvas c, HumanoidLook k, Pose p, _Skeleton s) {
  if (k.cloak == null) return;
  final sway = p.cloakSway;
  final l = s.shoulder + Offset(-k.torsoW * 0.62, 0);
  final r = s.shoulder + Offset(k.torsoW * 0.62, 0);
  final path = Path()
    ..moveTo(l.dx, l.dy)
    ..quadraticBezierTo(l.dx - 4 - sway * 4, s.hip.dy - 6, l.dx - 6 - sway * 8, s.hip.dy + 14)
    ..lineTo(l.dx + 4 - sway * 6, s.hip.dy + 10)
    ..lineTo(s.hip.dx - sway * 6, s.hip.dy + 18)
    ..lineTo(r.dx - 4 - sway * 6, s.hip.dy + 10)
    ..lineTo(r.dx + 4 - sway * 8, s.hip.dy + 15)
    ..quadraticBezierTo(r.dx + 4 - sway * 2, s.hip.dy - 6, r.dx, r.dy)
    ..quadraticBezierTo(s.shoulder.dx, s.shoulder.dy - 6, l.dx, l.dy)
    ..close();
  inked(c, path, k.cloak!, outline: 2.4);
  if (k.cloakTrim != null) {
    // Leaf-shaped trim along the hem.
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final p0 = Offset.lerp(Offset(l.dx - 6 - sway * 8, s.hip.dy + 12), Offset(r.dx + 4 - sway * 8, s.hip.dy + 13), t)!;
      final leaf = ellipsePath(p0 + const Offset(0, 2), 4, 6);
      inked(c, leaf, k.cloakTrim!, outline: 1.4);
    }
  }
}

void _drawQuiver(Canvas c, HumanoidLook k, _Skeleton s, {required bool front}) {
  final base = s.shoulder + Offset(front ? -10 : -4, 22);
  final top = s.shoulder + Offset(front ? -2 : 8, -8);
  final dir = top - base;
  final n = Offset(-dir.dy, dir.dx) / dir.distance;
  final body = polygon([base - n * 5, base + n * 5, top + n * 6, top - n * 6]);
  // Arrows sticking out.
  for (var i = -1; i <= 1; i++) {
    final a = top + n * (i * 3.5);
    final b = a + dir / dir.distance * 12 + n * (i * 1.5);
    strokeLine(c, a, b, hex(0x8a5a32), 1.8);
    final fl = polygon([b, b + n * 3 - dir / dir.distance * 4, b - n * 3 - dir / dir.distance * 4]);
    c.drawPath(fl, Paint()..color = i == 0 ? hex(0xf0f0f0) : hex(0xd8443a));
  }
  inked(c, body, hex(0x8a5a32), outline: 2);
  strokeLine(c, Offset.lerp(base, top, 0.25)! - n * 5, Offset.lerp(base, top, 0.25)! + n * 5, hex(0xe0b050), 2);
}

void _drawBackpack(Canvas c, HumanoidLook k, _Skeleton s, {required bool front}) {
  final center = s.shoulder + Offset(front ? -12 : -2, 12);
  final pack = roundRectPath(Rect.fromCenter(center: center, width: 30, height: 38), 8);
  inked(c, pack, hex(0x9a6436), outline: 2.2);
  inked(c, roundRectPath(Rect.fromCenter(center: center + const Offset(0, -12), width: 32, height: 12), 5), hex(0xb07a45), outline: 2);
  // Pots and pans dangling.
  inkedBall(c, circlePath(center + const Offset(-14, 10), 6), hex(0x8a96a3), outline: 1.6);
  inkedLine(c, center + const Offset(12, -20), center + const Offset(16, -34), hex(0x6b4426), 2.4, outline: 1);
  inked(c, ellipsePath(center + const Offset(0, -24), 10, 6), hex(0xd8c08a), outline: 1.6);
}

// ---------------------------------------------------------------------------
// Head
// ---------------------------------------------------------------------------

void _drawHead(Canvas c, HumanoidLook k, Pose p, _Skeleton s, {required bool back}) {
  final h = s.head;
  final r = k.headR;
  c.save();
  c.translate(h.dx, h.dy);
  c.rotate(p.lean * 0.5 + p.headTilt);

  // Back hair mass.
  if (!back) _hairBack(c, k, r, p);

  // Ears (far ear first).
  _ears(c, k, r, back: back, near: false);

  // Head shape.
  final headPath = k.nose == 'goblin'
      ? smoothClosed([
          Offset(-r, -r * 0.1),
          Offset(-r * 0.7, -r * 0.85),
          Offset(r * 0.1, -r * 1.02),
          Offset(r * 0.85, -r * 0.6),
          Offset(r * 1.02, r * 0.15),
          Offset(r * 0.6, r * 0.82),
          Offset(-r * 0.2, r * 0.9),
          Offset(-r * 0.85, r * 0.55),
        ])
      : circlePath(Offset.zero, r);
  inkedBall(c, headPath, k.skin, outline: 2.4);

  if (back) {
    _hairBackView(c, k, r);
    _ears(c, k, r, back: true, near: true);
    _headgear(c, k, r, back: true);
    c.restore();
    return;
  }

  // Face.
  _face(c, k, r, p);
  _hairFront(c, k, r);
  _ears(c, k, r, back: false, near: true);
  if (k.beard != 'none') _beard(c, k, r);
  _headgear(c, k, r, back: false);
  c.restore();
}

void _ears(Canvas c, HumanoidLook k, double r, {required bool back, required bool near}) {
  // In the front view the near ear sits on the left (back of the head), the
  // far ear peeks out on the right. Goblin ears are big enough to show both.
  if (k.ears == 'human') {
    if (near) {
      final x = back ? r * 0.7 : -r * 0.55;
      inkedBall(c, ellipsePath(Offset(x, r * 0.1), r * 0.2, r * 0.27), k.skin, outline: 1.8);
    }
    return;
  }
  if (k.ears == 'elf') {
    if (!near) return;
    final x = back ? r * 0.75 : -r * 0.62;
    final dirX = back ? 1.0 : -1.0;
    final ear = Path()
      ..moveTo(x, r * 0.25)
      ..quadraticBezierTo(x + dirX * r * 0.45, -r * 0.05, x + dirX * r * 0.85, -r * 0.55)
      ..quadraticBezierTo(x + dirX * r * 0.3, -r * 0.2, x, -r * 0.15)
      ..close();
    inked(c, ear, k.skin, outline: 1.8);
    return;
  }
  // Goblin: huge horizontal ears.
  final dirX = near ? (back ? 1.0 : -1.0) : (back ? -1.0 : 1.0);
  final x = dirX * r * 0.78;
  final size = near ? 1.0 : 0.82;
  final ear = Path()
    ..moveTo(x, -r * 0.35)
    ..quadraticBezierTo(x + dirX * r * 0.9 * size, -r * 0.75 * size, x + dirX * r * 1.55 * size, -r * 0.55 * size)
    ..quadraticBezierTo(x + dirX * r * 0.95 * size, r * 0.05, x, r * 0.3)
    ..close();
  inked(c, ear, near ? k.skin : shade(k.skin, -0.1), outline: 2);
  final inner = Path()
    ..moveTo(x + dirX * r * 0.15, -r * 0.2)
    ..quadraticBezierTo(x + dirX * r * 0.8 * size, -r * 0.5 * size, x + dirX * r * 1.25 * size, -r * 0.48 * size)
    ..quadraticBezierTo(x + dirX * r * 0.8 * size, -r * 0.05, x + dirX * r * 0.15, r * 0.12)
    ..close();
  c.drawPath(inner, Paint()..color = withAlpha(hex(0xd98a8a), 0.55));
}

void _face(Canvas c, HumanoidLook k, double r, Pose p) {
  final eyeY = r * 0.08;
  final e1 = Offset(r * 0.12, eyeY); // far-side (left) eye, closer to centre
  final e2 = Offset(r * 0.6, eyeY - 1); // near the facing edge
  final eyeW = r * 0.2, eyeH = r * 0.3;
  final ink = hex(0x221812);
  switch (p.face) {
    case 'dead':
      for (final e in [e1, e2]) {
        strokeLine(c, e + Offset(-eyeW, -eyeW), e + Offset(eyeW, eyeW), ink, 2.2);
        strokeLine(c, e + Offset(-eyeW, eyeW), e + Offset(eyeW, -eyeW), ink, 2.2);
      }
      break;
    case 'hurt':
      for (final e in [e1, e2]) {
        final path = Path()
          ..moveTo(e.dx - eyeW, e.dy - eyeW * 0.8)
          ..lineTo(e.dx + eyeW * 0.6, e.dy)
          ..lineTo(e.dx - eyeW, e.dy + eyeW * 0.8);
        c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = ink,
        );
      }
      break;
    case 'focus':
      // Far eye squinting, near eye wide and determined.
      strokeLine(c, e1 + Offset(-eyeW, 0), e1 + Offset(eyeW, 0), ink, 2.2);
      _eye(c, k, e2, eyeW, eyeH * 0.85);
      break;
    default:
      _eye(c, k, e1, eyeW * 0.85, eyeH * 0.95);
      _eye(c, k, e2, eyeW, eyeH);
  }
  // Brows.
  if (p.face == 'angry' || p.face == 'focus') {
    strokeLine(c, e1 + Offset(-eyeW, -eyeH * 1.1), e1 + Offset(eyeW, -eyeH * 0.6), shade(k.hair, -0.2), 2.4);
    strokeLine(c, e2 + Offset(-eyeW, -eyeH * 0.6), e2 + Offset(eyeW, -eyeH * 1.1), shade(k.hair, -0.2), 2.4);
  }
  // Nose.
  if (k.nose == 'goblin') {
    final nose = Path()
      ..moveTo(r * 0.3, r * 0.1)
      ..quadraticBezierTo(r * 1.15, r * 0.25, r * 0.95, r * 0.5)
      ..quadraticBezierTo(r * 0.6, r * 0.55, r * 0.35, r * 0.4)
      ..close();
    inked(c, nose, shade(k.skin, -0.06), outline: 1.8);
  } else if (k.nose == 'round') {
    inkedBall(c, circlePath(Offset(r * 0.52, r * 0.38), r * 0.16), shade(k.skin, -0.08), outline: 1.4);
  } else {
    strokeLine(c, Offset(r * 0.5, r * 0.28), Offset(r * 0.58, r * 0.4), withAlpha(shade(k.skin, -0.4), 0.8), 1.6);
  }
  // Blush.
  c.drawOval(Rect.fromCenter(center: Offset(r * 0.05, r * 0.45), width: r * 0.32, height: r * 0.16), Paint()..color = withAlpha(hex(0xff7b7b), 0.25));
  // Mouth.
  final m = Offset(r * 0.42, r * 0.62);
  if (p.face == 'angry' || p.face == 'hurt') {
    final mouth = ellipsePath(m, r * 0.16, r * 0.14);
    inked(c, mouth, hex(0x5a1e1e), outline: 1.6, gradient: false);
    if (k.fangs) {
      c.drawPath(polygon([m + Offset(-r * 0.12, -r * 0.08), m + Offset(-r * 0.06, r * 0.06), m + Offset(0, -r * 0.08)]), Paint()..color = hex(0xfff6e0));
    }
  } else if (p.face == 'dead') {
    strokeLine(c, m + Offset(-r * 0.15, 0), m + Offset(r * 0.15, 0), ink, 2);
  } else if (p.face == 'happy') {
    c.drawArc(
      Rect.fromCenter(center: m - Offset(0, r * 0.06), width: r * 0.36, height: r * 0.26),
      0.2,
      2.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  } else {
    c.drawArc(
      Rect.fromCenter(center: m - Offset(0, r * 0.04), width: r * 0.28, height: r * 0.16),
      0.3,
      2.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
    if (k.fangs) {
      c.drawPath(polygon([m + Offset(-r * 0.1, -r * 0.02), m + Offset(-r * 0.05, r * 0.14), m + Offset(0, -r * 0.02)]), Paint()..color = hex(0xfff6e0));
      c.drawPath(polygon([m + Offset(r * 0.06, -r * 0.0), m + Offset(r * 0.1, r * 0.12), m + Offset(r * 0.15, -r * 0.0)]), Paint()..color = hex(0xfff6e0));
    }
  }
}

void _eye(Canvas c, HumanoidLook k, Offset at, double w, double h) {
  inked(c, ellipsePath(at, w, h), hex(0xffffff), outline: 1.6, outlineColor: hex(0x221812), gradient: false);
  c.drawOval(Rect.fromCenter(center: at + Offset(w * 0.25, h * 0.12), width: w * 1.25, height: h * 1.35), Paint()..color = k.eyeColor);
  c.drawOval(Rect.fromCenter(center: at + Offset(w * 0.3, h * 0.15), width: w * 0.6, height: h * 0.7), Paint()..color = hex(0x120c08));
  c.drawCircle(at + Offset(-w * 0.05, -h * 0.25), w * 0.32, Paint()..color = hex(0xffffff));
}

void _hairBack(Canvas c, HumanoidLook k, double r, Pose p) {
  final sway = p.cloakSway;
  switch (k.hairStyle) {
    case 'long_wavy':
      final path = smoothClosed([
        Offset(-r * 0.2, -r * 1.0),
        Offset(-r * 1.15, -r * 0.4),
        Offset(-r * 1.35 - sway * 3, r * 0.6),
        Offset(-r * 1.2 - sway * 5, r * 1.6),
        Offset(-r * 0.7 - sway * 5, r * 2.0),
        Offset(-r * 0.4 - sway * 3, r * 1.3),
        Offset(r * 0.1, r * 0.4),
      ], tension: 0.55);
      inked(c, path, shade(k.hair, -0.1), outline: 2.2);
      break;
    case 'wild':
      final path = smoothClosed([
        Offset(-r * 0.1, -r * 1.15),
        Offset(-r * 1.2, -r * 0.7),
        Offset(-r * 1.5 - sway * 3, r * 0.3),
        Offset(-r * 1.35 - sway * 5, r * 1.3),
        Offset(-r * 0.8 - sway * 5, r * 1.9),
        Offset(-r * 0.2 - sway * 3, r * 1.4),
        Offset(r * 0.4, r * 0.6),
      ], tension: 0.6);
      inked(c, path, shade(k.hair, -0.1), outline: 2.2);
      // Feathers in the hair.
      for (var i = 0; i < 3; i++) {
        final base = Offset(-r * 0.9 - i * 4, r * 0.4 + i * 9);
        final tip = base + Offset(-12 - sway * 4, 8);
        final f = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(base.dx - 4, base.dy + 8, tip.dx, tip.dy)
          ..quadraticBezierTo(base.dx - 2, base.dy - 2, base.dx, base.dy)
          ..close();
        inked(c, f, i.isEven ? hex(0xf2e9d6) : hex(0xb06a3a), outline: 1.2);
      }
      break;
    case 'bun':
    case 'gray_bun':
      inkedBall(c, circlePath(Offset(-r * 0.6, -r * 0.85), r * 0.45), k.hair, outline: 2);
      break;
    case 'braids':
      for (final dx in [-0.75, -0.45]) {
        for (var i = 0; i < 4; i++) {
          inkedBall(c, ellipsePath(Offset(r * dx - sway * i, r * 0.5 + i * r * 0.32), r * 0.18, r * 0.2), k.hair, outline: 1.5);
        }
      }
      break;
    default:
      break;
  }
}

void _hairFront(Canvas c, HumanoidLook k, double r) {
  switch (k.hairStyle) {
    case 'none':
      return;
    case 'mohawk':
      for (var i = 0; i < 4; i++) {
        final x = -r * 0.5 + i * r * 0.32;
        final spike = polygon([Offset(x - 4, -r * 0.82), Offset(x + 2, -r * 1.45 + (i == 1 ? -4 : 0)), Offset(x + 6, -r * 0.82)]);
        inked(c, spike, k.hair, outline: 1.8);
      }
      return;
    case 'short':
    case 'bun':
    case 'gray_bun':
    case 'braids':
      final cap = Path()
        ..moveTo(-r * 1.02, r * 0.05)
        ..quadraticBezierTo(-r * 1.1, -r * 1.05, r * 0.05, -r * 1.06)
        ..quadraticBezierTo(r * 0.95, -r * 1.0, r * 1.0, -r * 0.2)
        ..quadraticBezierTo(r * 0.6, -r * 0.45, r * 0.3, -r * 0.3)
        ..quadraticBezierTo(r * 0.05, -r * 0.55, -r * 0.2, -r * 0.35)
        ..quadraticBezierTo(-r * 0.55, -r * 0.4, -r * 0.6, r * 0.1)
        ..close();
      inked(c, cap, k.hair, outline: 2.2);
      return;
    default:
      // Long / wild: bangs with a swoop and locks framing the face.
      final cap = Path()
        ..moveTo(-r * 1.05, r * 0.3)
        ..quadraticBezierTo(-r * 1.2, -r * 1.1, r * 0.1, -r * 1.12)
        ..quadraticBezierTo(r * 1.05, -r * 1.05, r * 1.06, -r * 0.1)
        ..quadraticBezierTo(r * 0.8, -r * 0.35, r * 0.62, -r * 0.2)
        ..quadraticBezierTo(r * 0.5, -r * 0.55, r * 0.15, -r * 0.42)
        ..quadraticBezierTo(-r * 0.2, -r * 0.62, -r * 0.35, -r * 0.3)
        ..quadraticBezierTo(-r * 0.62, -r * 0.1, -r * 0.62, r * 0.45)
        ..close();
      inked(c, cap, k.hair, outline: 2.2);
      // Shine.
      c.drawArc(
        Rect.fromCenter(center: Offset(-r * 0.2, -r * 0.62), width: r * 0.9, height: r * 0.5),
        3.5,
        1.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = withAlpha(shade(k.hair, 0.4), 0.7),
      );
      // Lock in front of the near ear.
      final lock = Path()
        ..moveTo(-r * 0.62, r * 0.0)
        ..quadraticBezierTo(-r * 0.8, r * 0.7, -r * 0.5, r * 1.1)
        ..quadraticBezierTo(-r * 0.45, r * 0.6, -r * 0.35, r * 0.1)
        ..close();
      inked(c, lock, k.hair, outline: 1.8);
  }
}

void _hairBackView(Canvas c, HumanoidLook k, double r) {
  if (k.hairStyle == 'none') return;
  if (k.hairStyle == 'mohawk') {
    _hairFront(c, k, r);
    return;
  }
  final long = k.hairStyle == 'long_wavy' || k.hairStyle == 'wild';
  final path = smoothClosed([
    Offset(-r * 1.02, -r * 0.1),
    Offset(-r * 0.75, -r * 0.92),
    Offset(r * 0.1, -r * 1.12),
    Offset(r * 0.9, -r * 0.75),
    Offset(r * 1.04, r * 0.1),
    Offset(r * 0.9, long ? r * 1.7 : r * 0.7),
    Offset(r * 0.1, long ? r * 1.95 : r * 0.95),
    Offset(-r * 0.85, long ? r * 1.6 : r * 0.7),
  ], tension: 0.5);
  inked(c, path, k.hair, outline: 2.2);
  for (var i = 0; i < 3; i++) {
    strokeLine(
      c,
      Offset(-r * 0.4 + i * r * 0.4, -r * 0.7),
      Offset(-r * 0.5 + i * r * 0.45, long ? r * 1.4 : r * 0.6),
      withAlpha(shade(k.hair, -0.3), 0.5),
      1.6,
    );
  }
  if (k.hairStyle == 'bun' || k.hairStyle == 'gray_bun') {
    inkedBall(c, circlePath(Offset(r * 0.05, -r * 0.95), r * 0.42), k.hair, outline: 2);
  }
  if (k.hairStyle == 'braids') {
    for (final dx in [-0.35, 0.4]) {
      for (var i = 0; i < 4; i++) {
        inkedBall(c, ellipsePath(Offset(r * dx, r * 0.7 + i * r * 0.32), r * 0.18, r * 0.2), k.hair, outline: 1.5);
      }
    }
  }
}

void _beard(Canvas c, HumanoidLook k, double r) {
  if (k.beard == 'mustache') {
    final m = Path()
      ..moveTo(r * 0.15, r * 0.48)
      ..quadraticBezierTo(r * 0.45, r * 0.32, r * 0.75, r * 0.48)
      ..quadraticBezierTo(r * 0.95, r * 0.62, r * 1.05, r * 0.45)
      ..quadraticBezierTo(r * 0.85, r * 0.75, r * 0.45, r * 0.58)
      ..quadraticBezierTo(r * 0.1, r * 0.75, -r * 0.1, r * 0.5)
      ..close();
    inked(c, m, k.hair, outline: 1.6);
  } else if (k.beard == 'braided') {
    final b = Path()
      ..moveTo(-r * 0.4, r * 0.3)
      ..quadraticBezierTo(r * 0.4, r * 0.55, r * 0.95, r * 0.25)
      ..quadraticBezierTo(r * 0.9, r * 1.2, r * 0.35, r * 1.75)
      ..quadraticBezierTo(-r * 0.1, r * 1.3, -r * 0.4, r * 0.3)
      ..close();
    inked(c, b, k.hair, outline: 2);
    for (var i = 0; i < 2; i++) {
      inked(c, roundRectPath(Rect.fromCenter(center: Offset(r * 0.3, r * (1.0 + i * 0.4)), width: 8, height: 4), 2), hex(0xffd36b), outline: 1);
    }
  }
}

void _headgear(Canvas c, HumanoidLook k, double r, {required bool back}) {
  final color = k.headgearColor ?? hex(0x8a8f99);
  switch (k.headgear) {
    case 'hood_down':
      // Hood bunched around the neck/shoulders.
      final hood = Path()
        ..moveTo(-r * 1.0, r * 0.55)
        ..quadraticBezierTo(-r * 0.2, r * 1.25, r * 0.9, r * 0.7)
        ..quadraticBezierTo(r * 0.6, r * 1.15, -r * 0.2, r * 1.2)
        ..quadraticBezierTo(-r * 1.0, r * 1.1, -r * 1.0, r * 0.55)
        ..close();
      inked(c, hood, color, outline: 2);
      break;
    case 'leaf_crown':
      for (var i = 0; i < 5; i++) {
        final a = math.pi + 0.35 + i * 0.6;
        final p = Offset(math.cos(a) * r * 0.95, math.sin(a) * r * 0.95);
        final leaf = Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(p.dx + math.cos(a + 0.6) * 8, p.dy + math.sin(a + 0.6) * 8, p.dx + math.cos(a) * 10, p.dy + math.sin(a) * 10)
          ..quadraticBezierTo(p.dx + math.cos(a - 0.6) * 8, p.dy + math.sin(a - 0.6) * 8, p.dx, p.dy)
          ..close();
        inked(c, leaf, i.isEven ? hex(0x6fcf4a) : hex(0xe0a33a), outline: 1.4);
      }
      break;
    case 'helmet':
      final helm = Path()
        ..moveTo(-r * 1.08, r * 0.0)
        ..quadraticBezierTo(-r * 1.1, -r * 1.2, r * 0.05, -r * 1.18)
        ..quadraticBezierTo(r * 1.1, -r * 1.15, r * 1.08, r * 0.0)
        ..lineTo(r * 0.85, -r * 0.08)
        ..quadraticBezierTo(0, -r * 0.35, -r * 0.85, -r * 0.08)
        ..close();
      inked(c, helm, color, outline: 2.2, light: 0.35);
      if (!back) {
        inked(c, roundRectPath(Rect.fromLTWH(r * 0.35, -r * 0.2, r * 0.18, r * 0.65), 2), color, outline: 1.6);
      }
      // Plume.
      final plume = Path()
        ..moveTo(-r * 0.2, -r * 1.15)
        ..quadraticBezierTo(-r * 0.9, -r * 1.7, -r * 1.5, -r * 1.2)
        ..quadraticBezierTo(-r * 0.8, -r * 1.3, -r * 0.1, -r * 0.95)
        ..close();
      inked(c, plume, hex(0x2e6fb5), outline: 1.8);
      break;
    case 'horned_helmet':
      final helm = Path()
        ..moveTo(-r * 1.1, -r * 0.1)
        ..quadraticBezierTo(-r * 1.1, -r * 1.25, 0, -r * 1.25)
        ..quadraticBezierTo(r * 1.1, -r * 1.25, r * 1.1, -r * 0.1)
        ..quadraticBezierTo(0, -r * 0.4, -r * 1.1, -r * 0.1)
        ..close();
      inked(c, helm, color, outline: 2.4, light: 0.35);
      for (final s in [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(s * r * 0.7, -r * 0.85)
          ..quadraticBezierTo(s * r * 1.6, -r * 1.2, s * r * 1.5, -r * 2.0)
          ..quadraticBezierTo(s * r * 1.2, -r * 1.35, s * r * 0.45, -r * 1.1)
          ..close();
        inked(c, horn, hex(0xf2e6cf), outline: 2);
      }
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(-r * 0.6 + i * r * 0.6, -r * 0.45), 2.4, Paint()..color = hex(0xd8d0c0));
      }
      break;
    case 'bandana':
      final band = Path()
        ..moveTo(-r * 1.0, -r * 0.35)
        ..quadraticBezierTo(0, -r * 1.25, r * 1.0, -r * 0.35)
        ..lineTo(r * 0.95, -r * 0.05)
        ..quadraticBezierTo(0, -r * 0.6, -r * 0.95, -r * 0.05)
        ..close();
      inked(c, band, color, outline: 2);
      final knot = Path()
        ..moveTo(-r * 0.95, -r * 0.2)
        ..lineTo(-r * 1.5, -r * 0.05)
        ..lineTo(-r * 1.35, r * 0.25)
        ..close();
      inked(c, knot, color, outline: 1.8);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(-r * 0.3 + i * r * 0.4, -r * 0.55), 1.8, Paint()..color = hex(0xfff2d6));
      }
      break;
    case 'skull_mask':
      // Feather headdress + skull mask worn on the forehead.
      for (var i = 0; i < 5; i++) {
        final a = math.pi * 1.15 + i * 0.28;
        final base = Offset(math.cos(a) * r * 0.8, math.sin(a) * r * 0.8);
        final tip = base + Offset(math.cos(a) * 18, math.sin(a) * 18);
        final f = Path()
          ..moveTo(base.dx - 3, base.dy)
          ..quadraticBezierTo((base.dx + tip.dx) / 2 - 5, (base.dy + tip.dy) / 2, tip.dx, tip.dy)
          ..quadraticBezierTo((base.dx + tip.dx) / 2 + 5, (base.dy + tip.dy) / 2, base.dx + 3, base.dy)
          ..close();
        inked(c, f, [hex(0xd8443a), hex(0x46b0d8), hex(0xffd36b)][i % 3], outline: 1.4);
      }
      if (!back) {
        final skull = smoothClosed([
          Offset(-r * 0.55, -r * 0.6),
          Offset(-r * 0.3, -r * 1.12),
          Offset(r * 0.5, -r * 1.12),
          Offset(r * 0.85, -r * 0.6),
          Offset(r * 0.6, -r * 0.3),
          Offset(-r * 0.3, -r * 0.3),
        ], tension: 0.45);
        inkedBall(c, skull, hex(0xf0e8d6), outline: 2);
        c.drawOval(Rect.fromCenter(center: Offset(r * 0.05, -r * 0.72), width: 7, height: 6), Paint()..color = hex(0x221812));
        c.drawOval(Rect.fromCenter(center: Offset(r * 0.48, -r * 0.72), width: 7, height: 6), Paint()..color = hex(0x221812));
      }
      break;
    case 'kerchief':
      final kf = Path()
        ..moveTo(-r * 1.05, -r * 0.1)
        ..quadraticBezierTo(-r * 0.9, -r * 1.2, r * 0.1, -r * 1.12)
        ..quadraticBezierTo(r * 1.0, -r * 1.0, r * 1.02, -r * 0.25)
        ..quadraticBezierTo(0, -r * 0.6, -r * 1.05, -r * 0.1)
        ..close();
      inked(c, kf, color, outline: 2);
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(-r * 0.5 + i * r * 0.35, -r * 0.75), 1.8, Paint()..color = hex(0xffffff));
      }
      break;
    case 'feathers':
      for (var i = 0; i < 2; i++) {
        final base = Offset(-r * 0.6 + i * 6, -r * 0.8);
        final tip = base + Offset(-10.0 + i * 4, -18);
        final f = Path()
          ..moveTo(base.dx - 2, base.dy)
          ..quadraticBezierTo(tip.dx - 5, (base.dy + tip.dy) / 2, tip.dx, tip.dy)
          ..quadraticBezierTo(tip.dx + 5, (base.dy + tip.dy) / 2, base.dx + 2, base.dy)
          ..close();
        inked(c, f, i == 0 ? hex(0xf2e9d6) : hex(0xb06a3a), outline: 1.4);
      }
      break;
  }
}

// ---------------------------------------------------------------------------
// Held items
// ---------------------------------------------------------------------------

void _drawFarHandItem(Canvas c, HumanoidLook k, Pose p, _Skeleton s) {
  if (k.weapon == 'shield') {
    final at = s.handB + const Offset(4, 0);
    inked(c, ellipsePath(at, 10, 13), hex(0x2e6fb5), outline: 2.2);
    c.drawCircle(at, 3, Paint()..color = hex(0xffd36b));
  }
}

void _drawNearHandItem(Canvas c, HumanoidLook k, Pose p, _Skeleton s) {
  final hand = s.handF;
  switch (k.weapon) {
    case 'bow':
      _bow(c, p, s);
      break;
    case 'club':
      final ang = -math.pi / 2 + 0.3 + p.swing;
      final tip = hand + polar(ang, 30 * k.bulk);
      final club = Path()
        ..moveTo(hand.dx, hand.dy)
        ..lineTo(tip.dx, tip.dy);
      inkedLine(c, hand - polar(ang, 4), tip, hex(0x8a5a32), 5 * k.bulk, outline: 1.8);
      inkedBall(c, ellipsePath(tip, 9 * k.bulk, 8 * k.bulk), hex(0x9a6436), outline: 2);
      for (var i = 0; i < 3; i++) {
        final sp = tip + polar(ang - 1.2 + i * 1.2, 9 * k.bulk);
        strokeLine(c, sp, sp + polar(ang - 1.2 + i * 1.2, 5), hex(0xc9d1d9), 2);
      }
      c.drawPath(club, Paint());
      break;
    case 'cleaver':
      final ang = -math.pi / 2 + 0.35 + p.swing;
      final dir = polar(ang, 1);
      final n = Offset(-dir.dy, dir.dx);
      final base = hand + dir * 6;
      final tip = hand + dir * 52;
      inkedLine(c, hand - dir * 8, base, hex(0x6b4426), 6, outline: 1.8);
      final blade = polygon([base + n * 4, tip + n * 10, tip - n * 12, tip - n * 12 - dir * 8, base - n * 12]);
      inked(c, blade, hex(0xc9d1d9), outline: 2.4, light: 0.4);
      strokeLine(c, base + n * 2, tip + n * 6, withAlpha(hex(0xffffff), 0.7), 1.6);
      c.drawCircle(base - n * 6 + dir * 10, 2.6, Paint()..color = hex(0x6b4426));
      break;
    case 'sling':
      // Sling cord whirling: drawn as an arc from the hand with a pouch.
      final ang = p.swing;
      final pouch = hand + polar(ang - math.pi / 2, 18);
      strokeLine(c, hand, pouch, hex(0x7a4e2b), 1.6);
      inkedBall(c, circlePath(pouch, 4.5), hex(0x9c978c), outline: 1.4);
      if (p.draw > 0.1) {
        c.drawArc(
          Rect.fromCircle(center: hand, radius: 18),
          ang - math.pi / 2 - 1.8,
          1.6,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = withAlpha(hex(0xffffff), 0.5 * p.draw),
        );
      }
      break;
    case 'staff':
      final ang = -math.pi / 2 - 0.15 + p.swing;
      final top = hand + polar(ang, 34);
      final bottom = hand - polar(ang, 26);
      inkedLine(c, bottom, top, hex(0x7a4e2b), 4, outline: 1.6);
      inkedBall(c, ellipsePath(top + polar(ang, 4), 7, 6), hex(0xf0e8d6), outline: 1.6);
      c.drawCircle(top + polar(ang, 4) + const Offset(-2, -1), 1.6, Paint()..color = hex(0x221812));
      c.drawCircle(top + polar(ang, 4) + const Offset(2.5, -1), 1.6, Paint()..color = hex(0x221812));
      final gem = top + polar(ang, 13);
      c.drawCircle(gem, 10 + p.glow * 8, Paint()..shader = Gradient.radial(gem, 10 + p.glow * 8, [withAlpha(p.glowColor, 0.7), withAlpha(p.glowColor, 0)]));
      inkedBall(c, ellipsePath(gem, 4, 5.5), p.glowColor, outline: 1.4);
      break;
    case 'spear':
      final ang = -math.pi / 2 + 0.05 + p.swing;
      final top = hand + polar(ang, 46);
      final bottom = hand - polar(ang, 30);
      inkedLine(c, bottom, top, hex(0x8a5a32), 3.6, outline: 1.6);
      final dir = polar(ang, 1);
      final n = Offset(-dir.dy, dir.dx);
      inked(c, polygon([top - n * 5, top + dir * 16, top + n * 5]), hex(0xc9d1d9), outline: 1.8, light: 0.4);
      break;
    case 'hammer':
      final ang = -math.pi / 2 + 0.25 + p.swing;
      final dir = polar(ang, 1);
      final n = Offset(-dir.dy, dir.dx);
      final head = hand + dir * 26;
      inkedLine(c, hand - dir * 6, head, hex(0x8a5a32), 4.4, outline: 1.6);
      inked(
        c,
        polygon([head - n * 10 - dir * 6, head + n * 10 - dir * 6, head + n * 10 + dir * 6, head - n * 10 + dir * 6]),
        hex(0x8a96a3),
        outline: 2,
        light: 0.35,
      );
      break;
    case 'basket':
      final b = hand + const Offset(0, 8);
      inked(c, roundRectPath(Rect.fromCenter(center: b, width: 22, height: 14), 5), hex(0xc0904a), outline: 1.8);
      for (var i = 0; i < 4; i++) {
        c.drawCircle(b + Offset(-7 + i * 5.0, -8), 3.4, Paint()..color = i.isEven ? hex(0x4fc9a2) : hex(0x6fcf4a));
      }
      break;
  }
}

void _bow(Canvas c, Pose p, _Skeleton s) {
  final grip = s.handF;
  final aimDir = polar(p.aim, 1);
  final up = Offset(aimDir.dy, -aimDir.dx); // perpendicular, "up" side of the bow
  const half = 21.0;
  final topTip = grip + up * half - aimDir * 6;
  final botTip = grip - up * half - aimDir * 6;
  final belly = grip + aimDir * 6;
  // Limbs as a curved wooden stave.
  final stave = Path()
    ..moveTo(topTip.dx, topTip.dy)
    ..quadraticBezierTo((topTip + belly).dx / 2 + aimDir.dx * 6, (topTip + belly).dy / 2 + aimDir.dy * 6, belly.dx, belly.dy)
    ..quadraticBezierTo((botTip + belly).dx / 2 + aimDir.dx * 6, (botTip + belly).dy / 2 + aimDir.dy * 6, botTip.dx, botTip.dy);
  c.drawPath(
    stave,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.4
      ..strokeCap = StrokeCap.round
      ..color = hex(0x3a2412),
  );
  c.drawPath(
    stave,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = hex(0x9a6436),
  );
  // Leaf wraps.
  for (final t in [0.25, 0.75]) {
    final q = Offset.lerp(topTip, botTip, t)! + aimDir * 5;
    c.drawOval(Rect.fromCenter(center: q, width: 6, height: 4), Paint()..color = hex(0x6fcf4a));
  }
  // String pulled back toward the far hand.
  final pull = grip - aimDir * (6 + p.draw * 22);
  final stringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = hex(0xf3ead7);
  c.drawPath(
    Path()
      ..moveTo(topTip.dx, topTip.dy)
      ..lineTo(pull.dx, pull.dy)
      ..lineTo(botTip.dx, botTip.dy),
    stringPaint,
  );
  if (p.arrowNocked) {
    final tip = pull + aimDir * 40;
    strokeLine(c, pull, tip, hex(0x3a2412), 3.4);
    strokeLine(c, pull, tip, hex(0xd9b07a), 1.6);
    final head = polygon([tip + aimDir * 6, tip + up * 3, tip - up * 3]);
    inked(c, head, hex(0xc9d1d9), outline: 1.2);
    final fl = polygon([pull + aimDir * 6, pull - aimDir * 1 + up * 4, pull - aimDir * 1 - up * 4]);
    c.drawPath(fl, Paint()..color = hex(0x6fcf4a));
  }
}
