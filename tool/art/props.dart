// Generates prop images (trees, rocks, buildings, camp gear...) and the
// `props.tsx` image-collection tileset used by Tiled maps.
//
// Convention: every prop image has a "ground centre" at
// (width / 2, height - anchorY). The map editor places the image bottom at the
// object point; the engine converts it back to the ground centre using the
// `anchorY` tile property, then uses `collision` (radius, tiles) or
// `footprint` (w,h tiles) for blocking and the ground centre for depth sorting.
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';
import 'iso.dart';

class PropDef {
  PropDef(
    this.name,
    this.width,
    this.height,
    this.anchorY,
    this.draw, {
    this.kind = 'decor',
    this.collision = 0,
    this.footprint,
    this.layer = 'sorted',
    this.extra = const {},
  });

  final String name;
  final int width, height;
  final double anchorY;
  final void Function(Canvas c, Offset ground) draw;
  final String kind;
  final double collision;
  final String? footprint;
  final String layer;
  final Map<String, String> extra;
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

final _bark = hex(0x7a4e2b);
final _barkDark = hex(0x553319);
final _leaf = hex(0x4cae3e);
final _leafLight = hex(0x84d65c);
final _pineGreen = hex(0x2f8a4f);
final _stone = hex(0x9c978c);
final _wood = hex(0x9a6436);
final _woodLight = hex(0xc08a50);
final _plaster = hex(0xf0e2c4);
final _copper = hex(0xe58a3e);
final _cloth = [hex(0xa0522d), hex(0x7c8f2f), hex(0x8d5a3b), hex(0x5f7a3a), hex(0xb07a3a)];

// ---------------------------------------------------------------------------
// Trees
// ---------------------------------------------------------------------------

void _trunk(Canvas c, Offset g, double w, double h, {double lean = 0}) {
  final top = g + Offset(lean, -h);
  final path = Path()
    ..moveTo(g.dx - w * 0.75, g.dy + 2)
    ..quadraticBezierTo(g.dx - w * 0.45, g.dy - h * 0.3, top.dx - w * 0.35, top.dy)
    ..lineTo(top.dx + w * 0.35, top.dy)
    ..quadraticBezierTo(g.dx + w * 0.45, g.dy - h * 0.3, g.dx + w * 0.75, g.dy + 2)
    ..quadraticBezierTo(g.dx, g.dy + 6, g.dx - w * 0.75, g.dy + 2)
    ..close();
  inked(c, path, _bark, outline: 2.4);
  // Bark strokes.
  for (var i = 0; i < 3; i++) {
    final x = g.dx - w * 0.25 + i * w * 0.25;
    strokeLine(c, Offset(x, g.dy - 4), Offset(x + lean * 0.4, g.dy - h * 0.7), withAlpha(_barkDark, 0.6), 1.3);
  }
  // Roots.
  for (final s in [-1.0, 1.0]) {
    final root = Path()
      ..moveTo(g.dx + s * w * 0.4, g.dy - 6)
      ..quadraticBezierTo(g.dx + s * w * 0.9, g.dy - 2, g.dx + s * w * 1.25, g.dy + 3)
      ..lineTo(g.dx + s * w * 0.55, g.dy + 3)
      ..close();
    inked(c, root, _bark, outline: 2);
  }
}

/// Union-outlined cluster of leafy circles.
void _canopy(Canvas c, List<(Offset, double)> balls, Color base, Color light, math.Random rng) {
  final out = outlineOf(base);
  for (final (p, r) in balls) {
    c.drawCircle(p, r + 2.6, Paint()..color = out);
  }
  for (final (p, r) in balls) {
    c.drawCircle(p, r, Paint()..shader = Gradient.radial(p + Offset(-r * 0.35, -r * 0.45), r * 1.35, [light, base, shade(base, -0.28)], const [0.0, 0.5, 1.0]));
  }
  // Highlight leaf tufts and darker clumps.
  for (final (p, r) in balls) {
    for (var i = 0; i < 3; i++) {
      final a = -2.4 + rng.nextDouble() * 1.2;
      final q = p + polar(a, r * (0.3 + rng.nextDouble() * 0.4));
      c.drawOval(Rect.fromCenter(center: q, width: r * 0.42, height: r * 0.26), Paint()..color = withAlpha(shade(light, 0.2), 0.75));
    }
    for (var i = 0; i < 2; i++) {
      final a = 0.4 + rng.nextDouble() * 1.6;
      final q = p + polar(a, r * (0.45 + rng.nextDouble() * 0.3));
      c.drawArc(
        Rect.fromCenter(center: q, width: r * 0.6, height: r * 0.4),
        0.2,
        2.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = withAlpha(shade(base, -0.4), 0.55),
      );
    }
  }
}

PropDef _oak(String name, int seed, {Color? leaf, Color? light, double scale = 1}) {
  final w = (220 * scale).round(), h = (270 * scale).round();
  return PropDef(
    name,
    w,
    h,
    18,
    (c, g) {
      final rng = math.Random(seed);
      groundShadow(c, g + const Offset(0, 4), 70 * scale, 30 * scale, 0.32);
      _trunk(c, g, 13 * scale, 120 * scale, lean: (rng.nextDouble() - 0.5) * 8);
      final cy = g.dy - 150 * scale;
      final balls = <(Offset, double)>[];
      for (var i = 0; i < 7; i++) {
        final a = i / 7 * math.pi * 2 + rng.nextDouble() * 0.5;
        balls.add((Offset(g.dx + math.cos(a) * 52 * scale, cy + math.sin(a) * 38 * scale), (34 + rng.nextDouble() * 12) * scale));
      }
      balls.add((Offset(g.dx, cy - 20 * scale), 46 * scale));
      balls.add((Offset(g.dx - 10 * scale, cy + 14 * scale), 40 * scale));
      _canopy(c, balls, leaf ?? _leaf, light ?? _leafLight, rng);
    },
    kind: 'tree',
    collision: 0.32 * scale,
  );
}

PropDef _pine(String name, int seed, {double scale = 1}) {
  final w = (150 * scale).round(), h = (300 * scale).round();
  return PropDef(
    name,
    w,
    h,
    16,
    (c, g) {
      final rng = math.Random(seed);
      groundShadow(c, g + const Offset(0, 3), 50 * scale, 22 * scale, 0.32);
      _trunk(c, g, 9 * scale, 60 * scale);
      const tiers = 4;
      for (var t = 0; t < tiers; t++) {
        final base = g.dy - (40 + t * 52) * scale;
        final half = (64 - t * 11) * scale;
        final top = base - 92 * scale;
        final pts = <Offset>[Offset(g.dx, top)];
        const teeth = 5;
        for (var i = 0; i <= teeth; i++) {
          final x = g.dx + half - i * (2 * half / teeth);
          final drop = i.isEven ? 10 * scale : 0.0;
          pts.add(Offset(x + (rng.nextDouble() - 0.5) * 4, base + drop));
        }
        final path = smoothClosed(pts, tension: 0.15);
        inked(c, path, shade(_pineGreen, -t * 0.02), outline: 2.6, light: 0.25, dark: 0.3);
        // Snow-free highlight on the lit side.
        final hl = Path()
          ..moveTo(g.dx - 2, top + 10)
          ..lineTo(g.dx - half * 0.55, base - 6)
          ..lineTo(g.dx - half * 0.2, base - 10)
          ..close();
        c.drawPath(hl, Paint()..color = withAlpha(hex(0x6fcf7f), 0.35));
      }
    },
    kind: 'tree',
    collision: 0.26 * scale,
  );
}

PropDef _deadTree(String name) => PropDef(
  name,
  200,
  250,
  16,
  (c, g) {
    groundShadow(c, g + const Offset(0, 3), 50, 20, 0.3);
    _trunk(c, g, 15, 130, lean: -6);
    void branch(Offset from, double angle, double len, double width, int depth) {
      final to = from + polar(angle, len);
      inkedLine(c, from, to, hex(0x5f4a3a), width, outline: 1.8);
      if (depth > 0) {
        branch(to, angle - 0.5, len * 0.65, width * 0.65, depth - 1);
        branch(to, angle + 0.45, len * 0.6, width * 0.6, depth - 1);
      }
    }

    final top = g + const Offset(-6, -128);
    branch(top, -math.pi / 2 - 0.5, 55, 9, 2);
    branch(top, -math.pi / 2 + 0.55, 60, 9, 2);
    branch(top + const Offset(2, 30), -0.3, 40, 7, 1);
  },
  kind: 'tree',
  collision: 0.3,
);

PropDef _stump(String name) => PropDef(
  name,
  80,
  70,
  14,
  (c, g) {
    groundShadow(c, g + const Offset(0, 2), 30, 12, 0.3);
    final body = Path()
      ..moveTo(g.dx - 20, g.dy)
      ..lineTo(g.dx - 18, g.dy - 26)
      ..lineTo(g.dx + 18, g.dy - 26)
      ..lineTo(g.dx + 20, g.dy)
      ..quadraticBezierTo(g.dx, g.dy + 8, g.dx - 20, g.dy)
      ..close();
    inked(c, body, _bark);
    inked(c, ellipsePath(g + const Offset(0, -26), 18, 8), hex(0xd9b07a), outline: 2);
    c.drawOval(
      Rect.fromCenter(center: g + const Offset(0, -26), width: 20, height: 8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = hex(0xa47844),
    );
  },
  kind: 'rock',
  collision: 0.25,
);

PropDef _log(String name) => PropDef(
  name,
  130,
  70,
  16,
  (c, g) {
    groundShadow(c, g + const Offset(0, 2), 52, 14, 0.3);
    final a = g + iso(-0.55, 0.15, 12), b = g + iso(0.55, -0.15, 12);
    inkedLine(c, a, b, _bark, 20, outline: 2.4);
    inked(c, ellipsePath(b, 9, 10), hex(0xd9b07a), outline: 2);
    strokeLine(c, a + const Offset(6, -4), b + const Offset(-10, -6), withAlpha(_barkDark, 0.5), 1.4);
  },
  kind: 'rock',
  collision: 0.3,
);

// ---------------------------------------------------------------------------
// Bushes, flora
// ---------------------------------------------------------------------------

PropDef _bush(String name, int seed, {bool berries = false}) => PropDef(
  name,
  110,
  80,
  12,
  (c, g) {
    final rng = math.Random(seed);
    groundShadow(c, g + const Offset(0, 2), 42, 14, 0.3);
    final balls = <(Offset, double)>[];
    for (var i = 0; i < 5; i++) {
      balls.add((g + Offset(-30 + i * 15.0, -18 - rng.nextDouble() * 14 - (i == 2 ? 10 : 0)), 16 + rng.nextDouble() * 6));
    }
    _canopy(c, balls, hex(0x3f9c3a), hex(0x77cc55), rng);
    if (berries) {
      for (var i = 0; i < 9; i++) {
        final p = g + Offset(-30 + rng.nextDouble() * 60, -40 + rng.nextDouble() * 26);
        inkedBall(c, circlePath(p, 3.2), hex(0xe0304a), outline: 1.2);
      }
    }
  },
  kind: 'bush',
  collision: 0.0,
);

PropDef _herb(String name, {bool picked = false}) => PropDef(
  name,
  96,
  96,
  14,
  (c, g) {
    c.save();
    c.translate(g.dx, g.dy);
    c.scale(1.45);
    c.translate(-g.dx, -g.dy);
    _herbBody(c, g, picked);
    c.restore();
  },
  kind: 'resource',
  collision: 0.0,
);

void _herbBody(Canvas c, Offset g, bool picked) {
  groundShadow(c, g + const Offset(0, 1), 18, 7, 0.28);
  if (picked) {
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + (i - 1.5) * 0.4;
      inkedLine(c, g, g + polar(a, 8), hex(0x6a9a4a), 2.4, outline: 1.2);
    }
    return;
  }
  final glow = Paint()..shader = Gradient.radial(g + const Offset(0, -18), 26, [withAlpha(hex(0x8ff7d0), 0.45), withAlpha(hex(0x8ff7d0), 0)]);
  c.drawCircle(g + const Offset(0, -18), 26, glow);
  for (var i = 0; i < 7; i++) {
    final a = -math.pi / 2 + (i - 3) * 0.38;
    final tip = g + polar(a, 26 + (i.isEven ? 4 : -2));
    final leaf = Path()
      ..moveTo(g.dx, g.dy)
      ..quadraticBezierTo((g.dx + tip.dx) / 2 + math.cos(a + 1.2) * 8, (g.dy + tip.dy) / 2 + math.sin(a + 1.2) * 8, tip.dx, tip.dy)
      ..quadraticBezierTo((g.dx + tip.dx) / 2 + math.cos(a - 1.2) * 8, (g.dy + tip.dy) / 2 + math.sin(a - 1.2) * 8, g.dx, g.dy)
      ..close();
    inked(c, leaf, i.isEven ? hex(0x4fc9a2) : hex(0x3aa37f), outline: 1.6);
  }
  for (var i = 0; i < 3; i++) {
    inkedBall(c, circlePath(g + Offset(-8 + i * 8.0, -26 - (i == 1 ? 6 : 0)), 3.4), hex(0xb9f0ff), outline: 1.2);
  }
}

PropDef _giantMushroom(String name, Color cap, int seed) => PropDef(
  name,
  120,
  140,
  12,
  (c, g) {
    final rng = math.Random(seed);
    groundShadow(c, g + const Offset(0, 2), 36, 14, 0.3);
    final stem = Path()
      ..moveTo(g.dx - 12, g.dy)
      ..quadraticBezierTo(g.dx - 9, g.dy - 40, g.dx - 10, g.dy - 70)
      ..lineTo(g.dx + 10, g.dy - 70)
      ..quadraticBezierTo(g.dx + 9, g.dy - 40, g.dx + 12, g.dy)
      ..quadraticBezierTo(g.dx, g.dy + 5, g.dx - 12, g.dy)
      ..close();
    inked(c, stem, hex(0xf2e6cf));
    final capPath = Path()
      ..moveTo(g.dx - 52, g.dy - 64)
      ..quadraticBezierTo(g.dx - 48, g.dy - 122, g.dx, g.dy - 124)
      ..quadraticBezierTo(g.dx + 48, g.dy - 122, g.dx + 52, g.dy - 64)
      ..quadraticBezierTo(g.dx, g.dy - 52, g.dx - 52, g.dy - 64)
      ..close();
    inkedBall(c, capPath, cap, outline: 2.6);
    for (var i = 0; i < 6; i++) {
      final p = g + Offset(-34 + rng.nextDouble() * 68, -110 + rng.nextDouble() * 38);
      c.drawOval(Rect.fromCenter(center: p, width: 11, height: 7), Paint()..color = withAlpha(hex(0xfff6e0), 0.9));
    }
  },
  kind: 'tree',
  collision: 0.22,
);

PropDef _mushroomCluster(String name) => PropDef(name, 80, 60, 10, (c, g) {
  groundShadow(c, g, 26, 9, 0.25);
  for (final (dx, s) in [(-14.0, 0.8), (10.0, 1.0), (-2.0, 0.6)]) {
    final b = g + Offset(dx, 0);
    inkedLine(c, b, b + Offset(0, -16 * s), hex(0xf2e6cf), 5 * s, outline: 1.4);
    final capPath = Path()
      ..moveTo(b.dx - 12 * s, b.dy - 14 * s)
      ..quadraticBezierTo(b.dx, b.dy - 32 * s, b.dx + 12 * s, b.dy - 14 * s)
      ..close();
    inkedBall(c, capPath, hex(0xe8463c), outline: 1.6);
    c.drawCircle(b + Offset(-3 * s, -22 * s), 2 * s, Paint()..color = hex(0xfff6e0));
  }
}, kind: 'decor');

// ---------------------------------------------------------------------------
// Rocks & ore
// ---------------------------------------------------------------------------

void _rockShape(Canvas c, Offset g, double rx, double ry, double h, int seed, Color base) {
  final rng = math.Random(seed);
  final pts = <Offset>[];
  const n = 9;
  for (var i = 0; i < n; i++) {
    final a = math.pi + i / (n - 1) * math.pi;
    final k = 0.85 + rng.nextDouble() * 0.25;
    pts.add(g + Offset(math.cos(a) * rx * k, -h * 0.25 + math.sin(a) * h * k));
  }
  pts.add(g + Offset(rx * 0.95, ry * 0.15));
  pts.add(g + Offset(rx * 0.3, ry * 0.6));
  pts.add(g + Offset(-rx * 0.35, ry * 0.55));
  pts.add(g + Offset(-rx * 0.95, ry * 0.1));
  final path = smoothClosed(pts, tension: 0.35);
  inkedBall(c, path, base, outline: 2.6, highlight: const Offset(-0.4, -0.5));
  // Facet lines.
  for (var i = 0; i < 2; i++) {
    final x = g.dx - rx * 0.3 + i * rx * 0.5;
    strokeLine(c, Offset(x, g.dy - h * 0.7), Offset(x + rx * 0.15, g.dy - h * 0.1), withAlpha(shade(base, -0.4), 0.5), 1.5);
  }
  c.drawOval(Rect.fromCenter(center: g + Offset(-rx * 0.35, -h * 0.75), width: rx * 0.5, height: h * 0.2), Paint()..color = withAlpha(shade(base, 0.35), 0.6));
}

PropDef _rock(String name, double size, int seed) {
  final w = (110 * size).round() + 20, h = (90 * size).round() + 20;
  return PropDef(
    name,
    w,
    h,
    10 + 12 * size,
    (c, g) {
      groundShadow(c, g + Offset(0, 6 * size), 50 * size, 18 * size, 0.3);
      _rockShape(c, g, 46 * size, 26 * size, 60 * size, seed, _stone);
      if (size > 0.9) {
        // Moss cap.
        final moss = Path()
          ..moveTo(g.dx - 30 * size, g.dy - 52 * size)
          ..quadraticBezierTo(g.dx - 4 * size, g.dy - 72 * size, g.dx + 22 * size, g.dy - 56 * size)
          ..quadraticBezierTo(g.dx, g.dy - 60 * size, g.dx - 30 * size, g.dy - 52 * size)
          ..close();
        c.drawPath(moss, Paint()..color = withAlpha(hex(0x5fae47), 0.85));
      }
    },
    kind: 'rock',
    collision: 0.42 * size,
  );
}

PropDef _ore(String name, {bool depleted = false}) => PropDef(
  name,
  120,
  110,
  18,
  (c, g) {
    groundShadow(c, g + const Offset(0, 6), 50, 18, 0.32);
    _rockShape(c, g, 44, 24, 54, 77, depleted ? hex(0x86817a) : hex(0x8e8a84));
    if (depleted) {
      for (var i = 0; i < 3; i++) {
        final p = g + Offset(-18 + i * 16.0, -30 + (i == 1 ? -10 : 0));
        c.drawCircle(p, 4, Paint()..color = withAlpha(hex(0x4a4640), 0.6));
      }
      return;
    }
    // Copper crystals poking out.
    final rng = math.Random(5);
    for (var i = 0; i < 5; i++) {
      final base = g + Offset(-26 + i * 13.0, -22 - rng.nextDouble() * 24);
      final a = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.2;
      final len = 14 + rng.nextDouble() * 12;
      final tip = base + polar(a, len);
      final side = polar(a + math.pi / 2, 5.5);
      final crystal = polygon([base - side, tip - side * 0.25, tip + side * 0.25, base + side]);
      inked(c, crystal, _copper, outline: 1.8, light: 0.35);
      strokeLine(c, base, tip, withAlpha(hex(0xffd7a8), 0.8), 1.4);
    }
    // Glints.
    for (final p in [g + const Offset(-14, -48), g + const Offset(16, -40)]) {
      c.drawCircle(p, 2.4, Paint()..color = hex(0xfff1c7));
      strokeLine(c, p + const Offset(-5, 0), p + const Offset(5, 0), withAlpha(hex(0xfff1c7), 0.8), 1);
      strokeLine(c, p + const Offset(0, -5), p + const Offset(0, 5), withAlpha(hex(0xfff1c7), 0.8), 1);
    }
  },
  kind: 'resource',
  collision: 0.4,
);

// ---------------------------------------------------------------------------
// Buckleburg buildings & furniture
// ---------------------------------------------------------------------------

PropDef _house(String name, Color roof, {bool alongU = true, bool smithy = false}) {
  const a = 1.25, b = 1.1;
  const wallH = 64.0;
  return PropDef(
    name,
    330,
    330,
    (a + b) * 32 + 14,
    (c, g) {
      groundShadow(c, g + const Offset(0, 8), 150, 70, 0.28);
      // Stone foundation + plaster walls.
      isoBox(c, g, a + 0.05, b + 0.05, 10, left: hex(0x9c958a), right: hex(0x837d72), top: hex(0xb3ad9f));
      isoBox(c, g, a, b, wallH, left: _plaster, right: shade(_plaster, -0.14), top: _plaster, z0: 10);
      // Timber framing.
      final beam = hex(0x6b4426);
      for (final s in [0.0, 0.33, 0.66, 1.0]) {
        inkedLine(c, leftFacePoint(g, a, b, s, 10), leftFacePoint(g, a, b, s, wallH + 10), beam, 4, outline: 1);
        inkedLine(c, rightFacePoint(g, a, b, s, 10), rightFacePoint(g, a, b, s, wallH + 10), beam, 4, outline: 1);
      }
      inkedLine(c, leftFacePoint(g, a, b, 0, 40), leftFacePoint(g, a, b, 1, 40), beam, 3.4, outline: 1);
      inkedLine(c, rightFacePoint(g, a, b, 0, 40), rightFacePoint(g, a, b, 1, 40), beam, 3.4, outline: 1);
      // Door on the left face, windows on both faces.
      inked(c, leftFaceQuad(g, a, b, 0.42, 0.62, 10, 52), hex(0x7b4a24), outline: 2);
      c.drawCircle(leftFacePoint(g, a, b, 0.58, 30), 2, Paint()..color = hex(0xffd36b));
      for (final s in [0.12, 0.74]) {
        inked(c, leftFaceQuad(g, a, b, s, s + 0.14, 46, 64), hex(0x8fd3ff), outline: 2, light: 0.4);
      }
      for (final s in [0.2, 0.62]) {
        inked(c, rightFaceQuad(g, a, b, s, s + 0.16, 46, 64), hex(0x8fd3ff), outline: 2, light: 0.4);
        // Flower box.
        inked(c, rightFaceQuad(g, a, b, s - 0.02, s + 0.18, 40, 46), hex(0x8a5a32), outline: 1.6);
        for (var i = 0; i < 4; i++) {
          c.drawCircle(rightFacePoint(g, a, b, s + i * 0.05, 48), 2.6, Paint()..color = i.isEven ? hex(0xff6f91) : hex(0xffd166));
        }
      }
      if (alongU) {
        gableRoofU(c, g, a, b, wallH + 10, 70, roof);
      } else {
        gableRoofV(c, g, a, b, wallH + 10, 70, roof);
      }
      // Chimney.
      final chimneyBase = g + iso(-0.6, -0.4, wallH + 60);
      isoBox(c, chimneyBase, 0.16, 0.16, 34, left: hex(0xa1503d), right: hex(0x873f30), top: hex(0x3b2a22));
      if (smithy) {
        // Anvil + glow beside the door.
        final anvilG = g + iso(0.1, b + 0.55);
        isoBox(c, anvilG, 0.14, 0.1, 12, left: hex(0x6a5a4e), right: hex(0x5a4b40), top: hex(0x7d6c5f));
        isoBox(c, anvilG + const Offset(0, -12), 0.28, 0.12, 9, left: hex(0x5d6670), right: hex(0x4b525a), top: hex(0x8a96a3));
      }
    },
    kind: 'structure',
    footprint: '${(a * 2).toStringAsFixed(2)},${(b * 2).toStringAsFixed(2)}',
  );
}

PropDef _well(String name) => PropDef(
  name,
  140,
  170,
  30,
  (c, g) {
    groundShadow(c, g + const Offset(0, 6), 56, 24, 0.3);
    // Stone cylinder.
    final body = Path()
      ..addRect(Rect.fromLTRB(g.dx - 40, g.dy - 34, g.dx + 40, g.dy))
      ..addOval(Rect.fromCenter(center: g, width: 80, height: 34));
    inked(c, body, _stone, outline: 2.4);
    inked(c, ellipsePath(g + const Offset(0, -34), 40, 17), shade(_stone, 0.15), outline: 2.4);
    inked(c, ellipsePath(g + const Offset(0, -34), 30, 12), hex(0x1f3b4a), outline: 1.6, gradient: false);
    for (var i = 0; i < 4; i++) {
      strokeLine(c, g + Offset(-40, -26 + i * 8.0), g + Offset(40, -26 + i * 8.0), withAlpha(hex(0x5f5a52), 0.4), 1.2);
    }
    // Posts and roof.
    inkedLine(c, g + const Offset(-34, -36), g + const Offset(-34, -112), _wood, 6);
    inkedLine(c, g + const Offset(34, -36), g + const Offset(34, -112), _wood, 6);
    inkedLine(c, g + const Offset(-34, -92), g + const Offset(34, -92), _woodLight, 4);
    final roof = polygon([g + const Offset(-56, -104), g + const Offset(0, -146), g + const Offset(56, -104)]);
    inked(c, roof, hex(0xb5452e), outline: 2.4);
    inkedLine(c, g + const Offset(6, -92), g + const Offset(6, -62), hex(0x8b6b4a), 1.6, outline: 0.8);
    inked(c, roundRectPath(Rect.fromCenter(center: g + const Offset(6, -56), width: 14, height: 12), 2), _wood, outline: 1.6);
  },
  kind: 'structure',
  collision: 0.55,
);

PropDef _questBoard(String name) => PropDef(
  name,
  130,
  150,
  18,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 44, 14, 0.3);
    inkedLine(c, g + const Offset(-36, 0), g + const Offset(-36, -110), _wood, 7);
    inkedLine(c, g + const Offset(36, 0), g + const Offset(36, -110), _wood, 7);
    inked(c, roundRectPath(Rect.fromLTRB(g.dx - 48, g.dy - 118, g.dx + 48, g.dy - 50), 4), hex(0xa8743f), outline: 2.6);
    final rng = math.Random(3);
    for (var i = 0; i < 5; i++) {
      final r = Rect.fromCenter(
        center: g + Offset(-30 + (i % 3) * 30.0 + rng.nextDouble() * 6, -100 + (i ~/ 3) * 28.0 + rng.nextDouble() * 6),
        width: 22,
        height: 18,
      );
      inked(c, Path()..addRect(r), hex(0xf6ecd2), outline: 1.4, gradient: false);
      strokeLine(c, r.topLeft + const Offset(4, 6), r.topRight + const Offset(-4, 6), hex(0x8a7a62), 1);
      strokeLine(c, r.topLeft + const Offset(4, 11), r.topRight + const Offset(-7, 11), hex(0x8a7a62), 1);
      c.drawCircle(r.topCenter + const Offset(0, 2), 2, Paint()..color = hex(0xd8443a));
    }
    final roof = polygon([g + const Offset(-60, -114), g + const Offset(0, -138), g + const Offset(60, -114)]);
    inked(c, roof, hex(0x6b8f3a), outline: 2.4);
  },
  kind: 'structure',
  collision: 0.4,
);

PropDef _signpost(String name) => PropDef(
  name,
  120,
  130,
  12,
  (c, g) {
    groundShadow(c, g, 18, 7, 0.3);
    inkedLine(c, g, g + const Offset(0, -100), _wood, 6);
    final s1 = polygon([g + const Offset(-6, -96), g + const Offset(40, -96), g + const Offset(50, -86), g + const Offset(40, -76), g + const Offset(-6, -76)]);
    final s2 = polygon([
      g + const Offset(6, -70),
      g + const Offset(-40, -70),
      g + const Offset(-50, -60),
      g + const Offset(-40, -50),
      g + const Offset(6, -50),
    ]);
    inked(c, s1, _woodLight, outline: 2);
    inked(c, s2, _woodLight, outline: 2);
    strokeLine(c, g + const Offset(2, -86), g + const Offset(34, -86), withAlpha(hex(0x5a3a1a), 0.6), 2);
    strokeLine(c, g + const Offset(-34, -60), g + const Offset(-2, -60), withAlpha(hex(0x5a3a1a), 0.6), 2);
  },
  kind: 'structure',
  collision: 0.15,
);

PropDef _crate(String name, {bool stack = false}) => PropDef(
  name,
  110,
  stack ? 130 : 90,
  26,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 40, 18, 0.3);
    void crate(Offset at) {
      isoBox(c, at, 0.28, 0.28, 32, left: _woodLight, right: _wood, top: shade(_woodLight, 0.12));
      inkedLine(c, leftFacePoint(at, 0.28, 0.28, 0.05, 4), leftFacePoint(at, 0.28, 0.28, 0.95, 28), shade(_wood, -0.15), 2.4, outline: 0.8);
      inkedLine(c, rightFacePoint(at, 0.28, 0.28, 0.05, 28), rightFacePoint(at, 0.28, 0.28, 0.95, 4), shade(_wood, -0.25), 2.4, outline: 0.8);
    }

    crate(g);
    if (stack) {
      crate(g + const Offset(0, -32));
    }
  },
  kind: 'structure',
  collision: 0.32,
);

PropDef _barrel(String name) => PropDef(
  name,
  80,
  90,
  16,
  (c, g) {
    groundShadow(c, g + const Offset(0, 3), 26, 11, 0.3);
    final body = Path()
      ..moveTo(g.dx - 20, g.dy - 2)
      ..quadraticBezierTo(g.dx - 27, g.dy - 26, g.dx - 20, g.dy - 50)
      ..lineTo(g.dx + 20, g.dy - 50)
      ..quadraticBezierTo(g.dx + 27, g.dy - 26, g.dx + 20, g.dy - 2)
      ..quadraticBezierTo(g.dx, g.dy + 6, g.dx - 20, g.dy - 2)
      ..close();
    inked(c, body, _wood);
    for (final y in [-12.0, -38.0]) {
      strokeLine(c, g + Offset(-23, y), g + Offset(23, y), hex(0x5d6670), 3.2);
    }
    inked(c, ellipsePath(g + const Offset(0, -50), 20, 8), _woodLight, outline: 2);
  },
  kind: 'structure',
  collision: 0.26,
);

PropDef _sack(String name) => PropDef(
  name,
  70,
  70,
  12,
  (c, g) {
    groundShadow(c, g + const Offset(0, 2), 22, 9, 0.28);
    final body = smoothClosed([
      g + const Offset(-18, 0),
      g + const Offset(-20, -22),
      g + const Offset(-8, -36),
      g + const Offset(8, -36),
      g + const Offset(20, -22),
      g + const Offset(18, 0),
    ]);
    inked(c, body, hex(0xd8c08a));
    strokeLine(c, g + const Offset(-8, -34), g + const Offset(8, -34), hex(0x8a6a3a), 2);
  },
  kind: 'decor',
  collision: 0.2,
);

PropDef _fence(String name, {required bool alongU}) => PropDef(
  name,
  150,
  110,
  40,
  (c, g) {
    final du = alongU ? 0.5 : 0.0, dv = alongU ? 0.0 : 0.5;
    final a = g + iso(-du, -dv), b = g + iso(du, dv);
    for (final t in [0.0, 0.5, 1.0]) {
      final p = Offset.lerp(a, b, t)!;
      inkedLine(c, p + const Offset(0, 4), p + const Offset(0, -44), _wood, 6);
    }
    for (final h in [-16.0, -34.0]) {
      inkedLine(c, a + Offset(0, h), b + Offset(0, h), _woodLight, 5, outline: 1.6);
    }
  },
  kind: 'structure',
  collision: 0.0,
  extra: {'wall': alongU ? 'u' : 'v'},
);

PropDef _lamp(String name) => PropDef(
  name,
  70,
  160,
  10,
  (c, g) {
    groundShadow(c, g, 16, 6, 0.3);
    inkedLine(c, g, g + const Offset(0, -118), hex(0x3d4752), 5);
    c.drawCircle(
      g + const Offset(0, -124),
      22,
      Paint()..shader = Gradient.radial(g + const Offset(0, -124), 22, [withAlpha(hex(0xffd36b), 0.6), withAlpha(hex(0xffd36b), 0)]),
    );
    inked(c, roundRectPath(Rect.fromCenter(center: g + const Offset(0, -124), width: 16, height: 20), 4), hex(0xffe08a), outline: 2);
    inked(c, polygon([g + const Offset(-12, -134), g + const Offset(0, -146), g + const Offset(12, -134)]), hex(0x3d4752), outline: 1.8);
  },
  kind: 'structure',
  collision: 0.12,
);

PropDef _hay(String name) => PropDef(
  name,
  100,
  80,
  16,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 36, 14, 0.3);
    isoBox(c, g, 0.3, 0.22, 30, left: hex(0xe5c25a), right: hex(0xc9a444), top: hex(0xf0d47a));
    for (var i = 0; i < 6; i++) {
      final s = 0.1 + i * 0.15;
      strokeLine(c, leftFacePoint(g, 0.3, 0.22, s, 4), leftFacePoint(g, 0.3, 0.22, s + 0.04, 26), withAlpha(hex(0xa4842e), 0.6), 1.2);
    }
  },
  kind: 'structure',
  collision: 0.3,
);

// ---------------------------------------------------------------------------
// Road / wagon / bridge
// ---------------------------------------------------------------------------

void _wheel(Canvas c, Offset center, double r, {bool broken = false}) {
  inked(c, ellipsePath(center, r * 0.55, r), hex(0x8a5a32), outline: 2.2, gradient: false);
  inked(c, ellipsePath(center, r * 0.38, r * 0.75), hex(0x3a2614), outline: 0, gradient: false);
  for (var i = 0; i < (broken ? 3 : 6); i++) {
    final a = i / 6 * math.pi * 2;
    strokeLine(c, center, center + Offset(math.cos(a) * r * 0.5, math.sin(a) * r * 0.95), hex(0xb07a45), 2.4);
  }
  c.drawCircle(center, 3, Paint()..color = hex(0x5d6670));
}

PropDef _wagon(String name, {bool broken = false}) => PropDef(
  name,
  230,
  190,
  50,
  (c, g) {
    groundShadow(c, g + const Offset(0, 10), 96, 34, 0.32);
    final tilt = broken ? 0.12 : 0.0;
    c.save();
    c.translate(g.dx, g.dy);
    c.rotate(tilt);
    c.translate(-g.dx, -g.dy);
    final bed = g + const Offset(0, -26);
    if (!broken) _wheel(c, bed + iso(-0.55, -0.4) + const Offset(0, 8), 18);
    _wheel(c, bed + iso(0.55, -0.4) + const Offset(0, 8), 18);
    isoBox(c, bed, 0.75, 0.42, 26, left: _woodLight, right: _wood, top: hex(0x6b4426));
    // Canvas cover.
    final cover = Path()
      ..moveTo((bed + iso(-0.75, 0.42, 26)).dx, (bed + iso(-0.75, 0.42, 26)).dy)
      ..quadraticBezierTo((bed + iso(-0.75, 0, 90)).dx, (bed + iso(-0.75, 0, 90)).dy, (bed + iso(-0.75, -0.42, 26)).dx, (bed + iso(-0.75, -0.42, 26)).dy)
      ..lineTo((bed + iso(0.75, -0.42, 26)).dx, (bed + iso(0.75, -0.42, 26)).dy)
      ..quadraticBezierTo((bed + iso(0.75, 0, 90)).dx, (bed + iso(0.75, 0, 90)).dy, (bed + iso(0.75, 0.42, 26)).dx, (bed + iso(0.75, 0.42, 26)).dy)
      ..close();
    inked(c, cover, hex(0xf3e6c4), outline: 2.4);
    for (final s in [-0.4, 0.0, 0.4]) {
      final p0 = bed + iso(s, 0.42, 26), p1 = bed + iso(s, 0, 84);
      strokeLine(c, p0, p1, withAlpha(hex(0xb59a6a), 0.7), 2);
    }
    if (broken) {
      // Patch + arrow stuck in the cover.
      inked(c, roundRectPath(Rect.fromCenter(center: bed + iso(0.1, 0.2, 60), width: 22, height: 16), 3), hex(0xc0392b), outline: 1.6);
      inkedLine(c, bed + iso(-0.3, 0.2, 70), bed + iso(-0.1, 0.4, 50), hex(0x6b4426), 2.4, outline: 1);
    }
    _wheel(c, bed + iso(0.55, 0.42) + const Offset(0, 8), 18, broken: broken);
    if (!broken) _wheel(c, bed + iso(-0.55, 0.42) + const Offset(0, 8), 18);
    c.restore();
    if (broken) {
      // Loose wheel on the ground.
      c.save();
      c.translate(g.dx - 70, g.dy + 4);
      c.scale(1, 0.5);
      inked(c, circlePath(Offset.zero, 18), hex(0x8a5a32), outline: 2.2, gradient: false);
      c.drawCircle(Offset.zero, 12, Paint()..color = hex(0x3a2614));
      c.restore();
    }
  },
  kind: 'structure',
  collision: 0.7,
);

PropDef _bridge(String name, {required bool alongU}) => PropDef(
  name,
  300,
  190,
  95,
  (c, g) {
    // Flat plank bridge, 3 tiles long, 1.2 wide. Rendered on the ground layer.
    final len = 1.5, wid = 0.55;
    Offset p(double s, double w) => alongU ? g + iso(s, w, 6) : g + iso(w, s, 6);
    final deck = polygon([p(-len, -wid), p(len, -wid), p(len, wid), p(-len, wid)]);
    // Support shadow on the water.
    c.drawPath(deck.shift(const Offset(0, 10)), Paint()..color = withAlpha(hex(0x0b2a3a), 0.45));
    inked(c, deck, _woodLight, outline: 2.6);
    for (var i = 1; i < 14; i++) {
      final s = -len + i * (2 * len / 14);
      strokeLine(c, p(s, -wid), p(s, wid), withAlpha(hex(0x6b4426), 0.65), 1.6);
    }
    for (final w in [-wid, wid]) {
      for (var i = 0; i <= 4; i++) {
        final s = -len + i * (2 * len / 4);
        inkedLine(c, p(s, w), p(s, w) + const Offset(0, -20), _wood, 4.4, outline: 1.4);
      }
      inkedLine(c, p(-len, w) + const Offset(0, -18), p(len, w) + const Offset(0, -18), _wood, 3.6, outline: 1.4);
    }
  },
  kind: 'structure',
  layer: 'ground',
  extra: {'walkable': alongU ? '3.0,1.1' : '1.1,3.0'},
);

// ---------------------------------------------------------------------------
// Goblin camp
// ---------------------------------------------------------------------------

PropDef _tent(String name, int seed) => PropDef(
  name,
  240,
  262,
  64,
  (c, g) {
    final rng = math.Random(seed);
    groundShadow(c, g + const Offset(0, 6), 100, 40, 0.3);
    const a = 0.9, b = 0.8;
    final apex = g + iso(0, 0, 150);
    final left = g + iso(-a, b), front = g + iso(a, b), right = g + iso(a, -b);
    final leftFace = polygon([left, front, apex]);
    final rightFace = polygon([front, right, apex]);
    inked(c, leftFace, _cloth[seed % _cloth.length], outline: 2.6);
    inked(c, rightFace, shade(_cloth[(seed + 2) % _cloth.length], -0.15), outline: 2.6);
    // Patches.
    for (var i = 0; i < 4; i++) {
      final t = 0.25 + rng.nextDouble() * 0.5, s = 0.2 + rng.nextDouble() * 0.6;
      final p = Offset.lerp(Offset.lerp(left, front, s)!, apex, t)!;
      inked(c, roundRectPath(Rect.fromCenter(center: p, width: 18, height: 14), 2), _cloth[(seed + i + 1) % _cloth.length], outline: 1.4);
      strokeLine(c, p + const Offset(-6, -4), p + const Offset(6, 4), withAlpha(hex(0xf0e0c0), 0.7), 0.9);
    }
    // Door flap.
    final door = polygon([Offset.lerp(left, front, 0.42)!, Offset.lerp(left, front, 0.72)!, Offset.lerp(Offset.lerp(left, front, 0.57)!, apex, 0.55)!]);
    inked(c, door, hex(0x2b1a10), outline: 2, gradient: false);
    // Poles sticking out of the apex + a skull ornament.
    inkedLine(c, apex, apex + const Offset(-14, -26), _wood, 4);
    inkedLine(c, apex, apex + const Offset(12, -24), _wood, 4);
    inkedBall(c, ellipsePath(apex + const Offset(-16, -30), 7, 6), hex(0xf2ead8), outline: 1.6);
  },
  kind: 'structure',
  collision: 0.85,
);

PropDef _campfire(String name) => PropDef(
  name,
  110,
  70,
  22,
  (c, g) {
    for (var i = 0; i < 9; i++) {
      final a = i / 9 * math.pi * 2;
      final p = g + Offset(math.cos(a) * 30, math.sin(a) * 14);
      inkedBall(c, ellipsePath(p, 8, 6), _stone, outline: 1.6);
    }
    inkedLine(c, g + const Offset(-18, 4), g + const Offset(16, -6), _bark, 7, outline: 1.6);
    inkedLine(c, g + const Offset(-14, -8), g + const Offset(18, 4), shade(_bark, -0.1), 7, outline: 1.6);
    c.drawCircle(g + const Offset(0, -2), 10, Paint()..color = withAlpha(hex(0x2b1a10), 0.6));
  },
  kind: 'structure',
  collision: 0.4,
  extra: {'emitter': 'fire'},
);

PropDef _totem(String name) => PropDef(
  name,
  90,
  180,
  12,
  (c, g) {
    groundShadow(c, g, 22, 9, 0.3);
    inkedLine(c, g, g + const Offset(0, -140), _wood, 9);
    // Stacked skulls & feathers.
    for (var i = 0; i < 3; i++) {
      final p = g + Offset(0, -60.0 - i * 30);
      inkedBall(c, ellipsePath(p, 14, 12), hex(0xf0e8d6), outline: 2);
      c.drawCircle(p + const Offset(-5, -1), 3.4, Paint()..color = hex(0x2b1a10));
      c.drawCircle(p + const Offset(5, -1), 3.4, Paint()..color = hex(0x2b1a10));
      strokeLine(c, p + const Offset(-4, 7), p + const Offset(4, 7), hex(0x2b1a10), 1.6);
    }
    for (final s in [-1.0, 1.0]) {
      final f = Path()
        ..moveTo(g.dx, g.dy - 136)
        ..quadraticBezierTo(g.dx + s * 26, g.dy - 160, g.dx + s * 18, g.dy - 172)
        ..quadraticBezierTo(g.dx + s * 6, g.dy - 150, g.dx, g.dy - 136)
        ..close();
      inked(c, f, s < 0 ? hex(0xd8443a) : hex(0x46b0d8), outline: 1.6);
    }
    // Glowing rune.
    c.drawCircle(
      g + const Offset(0, -24),
      10,
      Paint()..shader = Gradient.radial(g + const Offset(0, -24), 12, [withAlpha(hex(0x9bff6a), 0.9), withAlpha(hex(0x9bff6a), 0)]),
    );
  },
  kind: 'structure',
  collision: 0.22,
);

PropDef _banner(String name) => PropDef(
  name,
  90,
  170,
  10,
  (c, g) {
    groundShadow(c, g, 16, 6, 0.3);
    inkedLine(c, g, g + const Offset(0, -150), _wood, 6);
    final flag = Path()
      ..moveTo(g.dx + 2, g.dy - 146)
      ..lineTo(g.dx + 46, g.dy - 140)
      ..lineTo(g.dx + 36, g.dy - 120)
      ..lineTo(g.dx + 48, g.dy - 100)
      ..lineTo(g.dx + 2, g.dy - 104)
      ..close();
    inked(c, flag, hex(0x6f9a2a), outline: 2);
    // Crude goblin face.
    final f = g + const Offset(22, -124);
    c.drawCircle(f + const Offset(-5, 0), 3, Paint()..color = hex(0xffe066));
    c.drawCircle(f + const Offset(5, 0), 3, Paint()..color = hex(0xffe066));
    strokeLine(c, f + const Offset(-6, 8), f + const Offset(6, 8), hex(0x2b1a10), 2);
  },
  kind: 'structure',
  collision: 0.12,
);

PropDef _spikes(String name, {required bool alongU}) => PropDef(
  name,
  160,
  120,
  40,
  (c, g) {
    final du = alongU ? 0.55 : 0.0, dv = alongU ? 0.0 : 0.55;
    final a = g + iso(-du, -dv), b = g + iso(du, dv);
    inkedLine(c, a + const Offset(0, -10), b + const Offset(0, -10), _wood, 6, outline: 1.6);
    for (var i = 0; i <= 5; i++) {
      final p = Offset.lerp(a, b, i / 5)!;
      final tip = p + Offset(alongU ? -14 : 14, -52);
      final spike = polygon([p + const Offset(-5, 0), tip, p + const Offset(5, 0)]);
      inked(c, spike, _woodLight, outline: 1.8);
    }
  },
  kind: 'structure',
  collision: 0.0,
  extra: {'wall': alongU ? 'u' : 'v'},
);

PropDef _bones(String name) => PropDef(name, 100, 60, 14, (c, g) {
  final rng = math.Random(9);
  for (var i = 0; i < 6; i++) {
    final p = g + Offset(-30 + rng.nextDouble() * 60, -10 + rng.nextDouble() * 16);
    final a = rng.nextDouble() * math.pi;
    final d = polar(a, 9);
    inkedLine(c, p - d, p + d, hex(0xefe6d2), 3.2, outline: 1.2);
    c.drawCircle(p - d, 3, Paint()..color = hex(0xefe6d2));
    c.drawCircle(p + d, 3, Paint()..color = hex(0xefe6d2));
  }
  inkedBall(c, ellipsePath(g + const Offset(8, -12), 11, 9), hex(0xf0e8d6), outline: 1.8);
  c.drawCircle(g + const Offset(4, -13), 2.6, Paint()..color = hex(0x2b1a10));
  c.drawCircle(g + const Offset(12, -13), 2.6, Paint()..color = hex(0x2b1a10));
}, kind: 'decor');

PropDef _cauldron(String name) => PropDef(
  name,
  110,
  100,
  20,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 36, 14, 0.3);
    inkedLine(c, g + const Offset(-30, 4), g + const Offset(-22, -40), _wood, 4);
    inkedLine(c, g + const Offset(30, 4), g + const Offset(22, -40), _wood, 4);
    final pot = Path()
      ..moveTo(g.dx - 30, g.dy - 36)
      ..quadraticBezierTo(g.dx - 34, g.dy + 4, g.dx, g.dy + 2)
      ..quadraticBezierTo(g.dx + 34, g.dy + 4, g.dx + 30, g.dy - 36)
      ..close();
    inked(c, pot, hex(0x3d4148), outline: 2.4);
    inked(c, ellipsePath(g + const Offset(0, -36), 30, 10), hex(0x7fcf3a), outline: 2);
    for (final p in [const Offset(-10, -40), const Offset(8, -38)]) {
      c.drawCircle(g + p, 4, Paint()..color = hex(0xb5f06a));
    }
  },
  kind: 'structure',
  collision: 0.36,
);

PropDef _cage(String name) => PropDef(
  name,
  120,
  150,
  30,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 46, 18, 0.3);
    isoBox(c, g, 0.36, 0.36, 8, left: _wood, right: shade(_wood, -0.15), top: _woodLight);
    for (var i = 0; i <= 4; i++) {
      final s = i / 4;
      inkedLine(c, leftFacePoint(g, 0.36, 0.36, s, 8), leftFacePoint(g, 0.36, 0.36, s, 86), _wood, 3.4, outline: 1.2);
      inkedLine(c, rightFacePoint(g, 0.36, 0.36, s, 8), rightFacePoint(g, 0.36, 0.36, s, 86), _wood, 3.4, outline: 1.2);
    }
    isoBox(c, g, 0.38, 0.38, 6, left: _wood, right: shade(_wood, -0.15), top: _woodLight, z0: 86);
  },
  kind: 'structure',
  collision: 0.42,
);

// ---------------------------------------------------------------------------
// Grizzlefang's hollow
// ---------------------------------------------------------------------------

PropDef _honeyPot(String name) => PropDef(
  name,
  80,
  90,
  14,
  (c, g) {
    groundShadow(c, g + const Offset(0, 2), 24, 10, 0.3);
    final pot = Path()
      ..moveTo(g.dx - 16, g.dy - 50)
      ..quadraticBezierTo(g.dx - 34, g.dy - 22, g.dx - 18, g.dy)
      ..quadraticBezierTo(g.dx, g.dy + 6, g.dx + 18, g.dy)
      ..quadraticBezierTo(g.dx + 34, g.dy - 22, g.dx + 16, g.dy - 50)
      ..close();
    inkedBall(c, pot, hex(0xe0a33a), outline: 2.2);
    inked(c, ellipsePath(g + const Offset(0, -50), 17, 6), hex(0x8a5a22), outline: 2);
    final drip = Path()
      ..moveTo(g.dx - 10, g.dy - 50)
      ..quadraticBezierTo(g.dx - 12, g.dy - 34, g.dx - 6, g.dy - 30)
      ..quadraticBezierTo(g.dx - 2, g.dy - 36, g.dx + 2, g.dy - 50)
      ..close();
    inked(c, drip, hex(0xffc93c), outline: 1.4);
    inked(c, roundRectPath(Rect.fromCenter(center: g + const Offset(0, -22), width: 22, height: 12), 3), hex(0xf6ecd2), outline: 1.4);
  },
  kind: 'decor',
  collision: 0.2,
);

PropDef _clawTree(String name) {
  final base = _oak('${name}_base', 91, leaf: hex(0x5a9a3a), light: hex(0x8ccf5c));
  return PropDef(
    name,
    base.width,
    base.height,
    base.anchorY,
    (c, g) {
      base.draw(c, g);
      for (var i = 0; i < 3; i++) {
        final x = g.dx - 6 + i * 5.0;
        strokeLine(c, Offset(x, g.dy - 66), Offset(x + 6, g.dy - 34), hex(0xf2d7a8), 2.2);
      }
    },
    kind: 'tree',
    collision: base.collision,
  );
}

PropDef _caveMouth(String name) => PropDef(
  name,
  300,
  274,
  56,
  (c, g) {
    groundShadow(c, g + const Offset(0, 8), 130, 46, 0.32);
    final rock = smoothClosed([
      g + const Offset(-140, 10),
      g + const Offset(-128, -110),
      g + const Offset(-70, -190),
      g + const Offset(10, -206),
      g + const Offset(90, -176),
      g + const Offset(138, -96),
      g + const Offset(140, 12),
      g + const Offset(0, 30),
    ], tension: 0.4);
    inkedBall(c, rock, hex(0x8b867c), outline: 3, highlight: const Offset(-0.5, -0.6));
    final hole = smoothClosed([
      g + const Offset(-56, 12),
      g + const Offset(-58, -70),
      g + const Offset(-20, -112),
      g + const Offset(30, -108),
      g + const Offset(60, -64),
      g + const Offset(58, 12),
    ], tension: 0.5);
    c.drawPath(hole, Paint()..shader = Gradient.linear(g + const Offset(0, -110), g + const Offset(0, 14), [hex(0x050608), hex(0x1a1612)]));
    c.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = hex(0x2a2520),
    );
    // Glowing eyes in the dark (purely decorative, very ominous).
    for (final p in [const Offset(-12, -58), const Offset(10, -58)]) {
      c.drawCircle(g + p, 3.4, Paint()..color = hex(0xffd23f));
    }
    // Moss & vines.
    for (var i = 0; i < 6; i++) {
      final x = -100.0 + i * 40;
      final top = g + Offset(x, -150 + (i - 2.5).abs() * 18);
      c.drawOval(Rect.fromCenter(center: top, width: 46, height: 14), Paint()..color = withAlpha(hex(0x5fae47), 0.85));
    }
  },
  kind: 'structure',
  footprint: '2.60,1.20',
);

PropDef _brambles(String name, {required bool alongU}) => PropDef(
  name,
  170,
  130,
  40,
  (c, g) {
    final rng = math.Random(alongU ? 3 : 4);
    final du = alongU ? 0.6 : 0.0, dv = alongU ? 0.0 : 0.6;
    final a = g + iso(-du, -dv), b = g + iso(du, dv);
    for (var i = 0; i < 9; i++) {
      final p = Offset.lerp(a, b, i / 8)! + Offset(0, -10 - rng.nextDouble() * 20);
      final r = 14 + rng.nextDouble() * 10;
      inkedBall(c, blob(p, r, r * 0.8, rng), hex(0x3d6b2e), outline: 2);
    }
    for (var i = 0; i < 14; i++) {
      final p = Offset.lerp(a, b, rng.nextDouble())! + Offset(rng.nextDouble() * 20 - 10, -rng.nextDouble() * 40);
      final d = polar(rng.nextDouble() * math.pi * 2, 6);
      strokeLine(c, p, p + d, hex(0xe8d6a8), 1.6);
    }
    for (var i = 0; i < 4; i++) {
      final p = Offset.lerp(a, b, 0.15 + i * 0.22)! + const Offset(0, -34);
      c.drawCircle(p, 3.5, Paint()..color = hex(0xb02a4a));
    }
  },
  kind: 'structure',
  collision: 0.0,
  extra: {'wall': alongU ? 'u' : 'v'},
);

PropDef _ruinPillar(String name, {bool broken = false}) => PropDef(
  name,
  90,
  broken ? 120 : 190,
  16,
  (c, g) {
    groundShadow(c, g + const Offset(0, 3), 30, 12, 0.3);
    final h = broken ? 70.0 : 150.0;
    isoBox(c, g, 0.24, 0.24, 14, left: hex(0xbdb6a6), right: hex(0x9f988a), top: hex(0xd6cfbf));
    final shaft = Path()..addRect(Rect.fromLTRB(g.dx - 16, g.dy - h, g.dx + 16, g.dy - 14));
    inked(c, shaft, hex(0xc9c2b2), outline: 2.2);
    for (var i = 0; i < 3; i++) {
      strokeLine(c, g + Offset(-8 + i * 8.0, -16), g + Offset(-8 + i * 8.0, -h + 4), withAlpha(hex(0x8f8879), 0.6), 1.4);
    }
    if (broken) {
      final top = polygon([g + Offset(-17, -h), g + Offset(-8, -h - 12), g + Offset(4, -h - 4), g + Offset(17, -h - 16), g + Offset(17, -h)]);
      inked(c, top, hex(0xd6cfbf), outline: 2);
    } else {
      isoBox(c, g + Offset(0, -h), 0.3, 0.3, 14, left: hex(0xbdb6a6), right: hex(0x9f988a), top: hex(0xd6cfbf));
    }
    c.drawOval(Rect.fromCenter(center: g + Offset(-6, -h * 0.4), width: 18, height: 10), Paint()..color = withAlpha(hex(0x5fae47), 0.8));
  },
  kind: 'rock',
  collision: 0.3,
);

// ---------------------------------------------------------------------------
// Interactive objects
// ---------------------------------------------------------------------------

PropDef _waypoint(String name, {required bool active}) => PropDef(
  name,
  140,
  200,
  30,
  (c, g) {
    groundShadow(c, g + const Offset(0, 6), 52, 22, 0.3);
    // Circular stone dais.
    inked(c, ellipsePath(g, 54, 24), hex(0x8f897d), outline: 2.4);
    inked(c, ellipsePath(g + const Offset(0, -6), 46, 19), hex(0xb7b0a2), outline: 2);
    final rune = active ? hex(0x6ff3ff) : hex(0x6c7a86);
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * math.pi * 2;
      c.drawCircle(g + Offset(math.cos(a) * 34, -6 + math.sin(a) * 13), 3, Paint()..color = rune);
    }
    // Standing stone.
    final stone = smoothClosed([
      g + const Offset(-18, -8),
      g + const Offset(-22, -90),
      g + const Offset(-8, -150),
      g + const Offset(10, -152),
      g + const Offset(22, -96),
      g + const Offset(18, -8),
    ], tension: 0.3);
    inkedBall(c, stone, hex(0x7f8a99), outline: 2.6);
    // Rune glyph.
    final glyph = Path()
      ..moveTo(g.dx, g.dy - 128)
      ..lineTo(g.dx - 8, g.dy - 104)
      ..lineTo(g.dx + 8, g.dy - 92)
      ..lineTo(g.dx, g.dy - 64)
      ..moveTo(g.dx - 10, g.dy - 84)
      ..lineTo(g.dx + 10, g.dy - 84);
    if (active) {
      c.drawCircle(
        g + const Offset(0, -96),
        40,
        Paint()..shader = Gradient.radial(g + const Offset(0, -96), 44, [withAlpha(hex(0x6ff3ff), 0.45), withAlpha(hex(0x6ff3ff), 0)]),
      );
    }
    c.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = rune,
    );
  },
  kind: 'waypoint',
  collision: 0.45,
);

PropDef _chest(String name, {required bool open}) => PropDef(
  name,
  110,
  100,
  24,
  (c, g) {
    groundShadow(c, g + const Offset(0, 4), 40, 16, 0.32);
    const a = 0.36, b = 0.24;
    isoBox(c, g, a, b, 26, left: hex(0xa8642e), right: hex(0x8a4f22), top: hex(0x6b3a18));
    // Metal bands.
    for (final s in [0.15, 0.85]) {
      inkedLine(c, leftFacePoint(g, a, b, s, 0), leftFacePoint(g, a, b, s, 26), hex(0xe8b84a), 3.2, outline: 1);
    }
    if (open) {
      final lid = polygon([g + iso(-a, -b, 26), g + iso(a, -b, 26), g + iso(a, -b, 58), g + iso(-a, -b, 58)]);
      inked(c, lid, hex(0x9a5a28), outline: 2);
      c.drawPath(polygon([g + iso(-a, -b, 26), g + iso(a, -b, 26), g + iso(a, b, 26), g + iso(-a, b, 26)]), Paint()..color = hex(0xffd75e));
      for (var i = 0; i < 5; i++) {
        c.drawCircle(g + iso(-0.2 + i * 0.1, 0, 30), 4, Paint()..color = hex(0xfff1a6));
      }
    } else {
      // Domed lid.
      final lid = Path()
        ..moveTo((g + iso(-a, b, 26)).dx, (g + iso(-a, b, 26)).dy)
        ..lineTo((g + iso(a, b, 26)).dx, (g + iso(a, b, 26)).dy)
        ..quadraticBezierTo((g + iso(a, 0, 50)).dx, (g + iso(a, 0, 50)).dy, (g + iso(a, -b, 26)).dx, (g + iso(a, -b, 26)).dy)
        ..lineTo((g + iso(-a, -b, 26)).dx, (g + iso(-a, -b, 26)).dy)
        ..quadraticBezierTo((g + iso(-a, 0, 50)).dx, (g + iso(-a, 0, 50)).dy, (g + iso(-a, b, 26)).dx, (g + iso(-a, b, 26)).dy)
        ..close();
      inked(c, lid, hex(0xb8703a), outline: 2.2);
      inked(c, roundRectPath(Rect.fromCenter(center: leftFacePoint(g, a, b, 0.5, 22), width: 10, height: 12), 2), hex(0xffd75e), outline: 1.4);
    }
  },
  kind: 'chest',
  collision: 0.35,
);

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

List<PropDef> allProps() => [
  _oak('tree_oak_1', 11),
  _oak('tree_oak_2', 12, scale: 1.12),
  _oak('tree_oak_3', 13, scale: 0.9),
  _oak('tree_lime_1', 14, leaf: hex(0x7cc23a), light: hex(0xb8e86a)),
  _oak('tree_autumn_1', 15, leaf: hex(0xe8902a), light: hex(0xffc95a)),
  _oak('tree_autumn_2', 16, leaf: hex(0xd9622b), light: hex(0xff9a4a), scale: 0.95),
  _pine('tree_pine_1', 21),
  _pine('tree_pine_2', 22, scale: 1.15),
  _deadTree('tree_dead_1'),
  _clawTree('tree_clawed_1'),
  _stump('stump_1'),
  _log('log_1'),
  _bush('bush_1', 31),
  _bush('bush_2', 32),
  _bush('bush_berry_1', 33, berries: true),
  _giantMushroom('mushroom_giant_red', hex(0xe8463c), 41),
  _giantMushroom('mushroom_giant_purple', hex(0x9b5de5), 42),
  _mushroomCluster('mushroom_cluster_1'),
  _rock('rock_small_1', 0.45, 51),
  _rock('rock_medium_1', 0.75, 52),
  _rock('rock_large_1', 1.1, 53),
  _rock('rock_large_2', 1.3, 54),
  _ore('ore_copper'),
  _ore('ore_copper_depleted', depleted: true),
  _herb('herb_sniffleleaf'),
  _herb('herb_picked', picked: true),
  _house('house_red', hex(0xc0392b)),
  _house('house_blue', hex(0x2e6fb5), alongU: false),
  _house('house_smithy', hex(0x6d6a63), smithy: true),
  _well('well'),
  _questBoard('quest_board'),
  _signpost('signpost'),
  _crate('crate'),
  _crate('crate_stack', stack: true),
  _barrel('barrel'),
  _sack('sack'),
  _hay('haybale'),
  _lamp('lamp_post'),
  _fence('fence_u', alongU: true),
  _fence('fence_v', alongU: false),
  _wagon('wagon'),
  _wagon('wagon_broken', broken: true),
  _bridge('bridge_u', alongU: true),
  _bridge('bridge_v', alongU: false),
  _tent('goblin_tent_1', 1),
  _tent('goblin_tent_2', 3),
  _campfire('campfire'),
  _totem('goblin_totem'),
  _banner('goblin_banner'),
  _spikes('spikes_u', alongU: true),
  _spikes('spikes_v', alongU: false),
  _bones('bone_pile'),
  _cauldron('goblin_cauldron'),
  _cage('goblin_cage'),
  _honeyPot('honey_pot'),
  _caveMouth('cave_mouth'),
  _brambles('brambles_u', alongU: true),
  _brambles('brambles_v', alongU: false),
  _ruinPillar('ruin_pillar'),
  _ruinPillar('ruin_pillar_broken', broken: true),
  _waypoint('waypoint_stone', active: false),
  _waypoint('waypoint_stone_active', active: true),
  _chest('chest_closed', open: false),
  _chest('chest_open', open: true),
];

Future<void> generateProps(String tilesDir) async {
  final props = allProps();
  final previews = <(PropDef, Image)>[];
  for (final p in props) {
    final image = await renderImage(p.width, p.height, (c) {
      p.draw(c, Offset(p.width / 2, p.height - p.anchorY));
    });
    await savePng(image, '$tilesDir/props/${p.name}.png');
    previews.add((p, image));
  }
  writeText('$tilesDir/props.tsx', _propsTsx(props));

  // Contact sheet for review.
  const cols = 8;
  const cell = 340.0;
  final rows = (props.length / cols).ceil();
  final sheet = await renderImage((cols * cell).toInt(), (rows * cell).toInt(), (c) {
    c.drawRect(Rect.fromLTWH(0, 0, cols * cell, rows * cell), Paint()..color = hex(0x5fa845));
    for (var i = 0; i < previews.length; i++) {
      final (p, img) = previews[i];
      final x = (i % cols) * cell, y = (i ~/ cols) * cell;
      final ground = Offset(x + cell / 2, y + cell - 40);
      c.drawImage(img, ground - Offset(p.width / 2, p.height - p.anchorY), Paint());
      c.drawCircle(ground, 3, Paint()..color = hex(0xff0000));
    }
  });
  await savePng(sheet, 'build/art_preview/props_sheet.png');
}

String _propsTsx(List<PropDef> props) {
  var maxW = 0, maxH = 0;
  for (final p in props) {
    maxW = math.max(maxW, p.width);
    maxH = math.max(maxH, p.height);
  }
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<tileset version="1.10" tiledversion="1.11.0" name="props" tilewidth="$maxW" '
      'tileheight="$maxH" tilecount="${props.length}" columns="0" objectalignment="bottom">',
    )
    ..writeln(' <grid orientation="orthogonal" width="1" height="1"/>');
  for (var i = 0; i < props.length; i++) {
    final p = props[i];
    b
      ..writeln(' <tile id="$i" type="${p.kind}">')
      ..writeln('  <properties>')
      ..writeln('   <property name="name" value="${p.name}"/>')
      ..writeln('   <property name="anchorY" type="float" value="${p.anchorY}"/>');
    if (p.collision > 0) b.writeln('   <property name="collision" type="float" value="${p.collision.toStringAsFixed(3)}"/>');
    if (p.footprint != null) b.writeln('   <property name="footprint" value="${p.footprint}"/>');
    if (p.layer != 'sorted') b.writeln('   <property name="layer" value="${p.layer}"/>');
    p.extra.forEach((k, v) => b.writeln('   <property name="$k" value="$v"/>'));
    b
      ..writeln('  </properties>')
      ..writeln('  <image source="props/${p.name}.png" width="${p.width}" height="${p.height}"/>')
      ..writeln(' </tile>');
  }
  b.writeln('</tileset>');
  return b.toString();
}
