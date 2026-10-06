// UI icons (abilities, items, materials, day jobs) at 128x128.
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';

const _size = 128.0;
const _c = Offset(64, 64);

typedef IconPainter = void Function(Canvas c);

void _arrow(Canvas c, Offset from, Offset to, {Color shaft = const Color(0xffd9b07a), Color fletch = const Color(0xff6fcf4a), double w = 6}) {
  final d = (to - from) / (to - from).distance;
  final n = Offset(-d.dy, d.dx);
  inkedLine(c, from, to - d * 10, shaft, w, outline: 2.4);
  inked(c, polygon([to + d * 6, to - d * 14 + n * 9, to - d * 14 - n * 9]), hex(0xd6dde4), outline: 2.4, light: 0.4);
  inked(c, polygon([from + d * 4, from - d * 10 + n * 9, from - d * 6, from - d * 10 - n * 9]), fletch, outline: 2.2);
}

void _glow(Canvas c, Offset at, double r, Color color, [double a = 0.6]) {
  c.drawCircle(at, r, Paint()..shader = Gradient.radial(at, r, [withAlpha(color, a), withAlpha(color, 0)]));
}

void _potion(Canvas c, Color liquid) {
  _glow(c, _c + const Offset(0, 14), 52, liquid, 0.35);
  final flask = Path()
    ..moveTo(52, 30)
    ..lineTo(52, 50)
    ..quadraticBezierTo(24, 62, 28, 88)
    ..quadraticBezierTo(34, 112, 64, 112)
    ..quadraticBezierTo(94, 112, 100, 88)
    ..quadraticBezierTo(104, 62, 76, 50)
    ..lineTo(76, 30)
    ..close();
  inked(c, flask, hex(0xdff4ff), outline: 3, light: 0.3);
  final fill = Path()
    ..moveTo(31, 80)
    ..quadraticBezierTo(64, 70, 97, 80)
    ..quadraticBezierTo(96, 108, 64, 109)
    ..quadraticBezierTo(32, 108, 31, 80)
    ..close();
  inkedBall(c, fill, liquid, outline: 0);
  c.drawOval(const Rect.fromLTWH(40, 64, 12, 22), Paint()..color = withAlpha(hex(0xffffff), 0.6));
  inked(c, roundRectPath(const Rect.fromLTWH(48, 18, 32, 16), 5), hex(0xa8743f), outline: 2.6);
}

void _bowShape(Canvas c, {Color wood = const Color(0xff9a6436), Color? glow}) {
  if (glow != null) _glow(c, _c, 60, glow, 0.5);
  final stave = Path()
    ..moveTo(36, 16)
    ..quadraticBezierTo(104, 30, 100, 64)
    ..quadraticBezierTo(104, 98, 36, 112);
  c.drawPath(
    stave,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..color = outlineOf(wood),
  );
  c.drawPath(
    stave,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = wood,
  );
  strokeLine(c, const Offset(36, 16), const Offset(36, 112), hex(0xf3ead7), 2.4);
  inked(c, roundRectPath(const Rect.fromLTWH(92, 54, 16, 20), 4), hex(0x6b4426), outline: 2.2);
  for (final y in [34.0, 94.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(y < 64 ? 82 : 82, y), width: 14, height: 9), Paint()..color = hex(0x6fcf4a));
  }
}

final Map<String, IconPainter> iconPainters = {
  // --- Abilities -----------------------------------------------------------
  'ability_quick_shot': (c) {
    for (var i = 0; i < 3; i++) {
      strokeLine(c, Offset(14, 70 + i * 12.0), Offset(46, 62 + i * 12.0), withAlpha(hex(0xffffff), 0.6), 4);
    }
    _arrow(c, const Offset(24, 96), const Offset(108, 28));
  },
  'ability_precision_shot': (c) {
    _glow(c, const Offset(96, 36), 40, hex(0xffe066), 0.8);
    inked(c, circlePath(const Offset(96, 36), 24), hex(0xf6ecd2), outline: 3);
    inked(c, circlePath(const Offset(96, 36), 15), hex(0xd8443a), outline: 2.4);
    inked(c, circlePath(const Offset(96, 36), 6), hex(0xf6ecd2), outline: 2);
    for (var i = 0; i < 4; i++) {
      strokeLine(c, Offset(10.0 + i * 8, 118.0 - i * 8), Offset(30.0 + i * 8, 98.0 - i * 8), withAlpha(hex(0xffe066), 0.8), 4);
    }
    _arrow(c, const Offset(22, 106), const Offset(98, 34), shaft: hex(0xffe9a8), fletch: hex(0xffc94f));
  },
  'ability_multi_shot': (c) {
    _arrow(c, const Offset(20, 108), const Offset(76, 18));
    _arrow(c, const Offset(20, 108), const Offset(110, 50));
    _arrow(c, const Offset(20, 108), const Offset(100, 96));
  },
  'ability_vine_trap': (c) {
    _glow(c, _c, 60, hex(0x8bff5a), 0.5);
    for (var i = 0; i < 3; i++) {
      final r = 40.0 - i * 10;
      c.drawOval(
        Rect.fromCenter(center: _c + const Offset(0, 16), width: r * 2.4, height: r * 1.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = outlineOf(hex(0x3f9a30)),
      );
      c.drawOval(
        Rect.fromCenter(center: _c + const Offset(0, 16), width: r * 2.4, height: r * 1.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = hex(0x5fbf3a),
      );
    }
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * math.pi * 2;
      final base = _c + Offset(math.cos(a) * 40, 16 + math.sin(a) * 18);
      final tip = base + Offset(math.cos(a) * 6, -34);
      final vine = Path()
        ..moveTo(base.dx - 5, base.dy)
        ..quadraticBezierTo(base.dx - 10, (base.dy + tip.dy) / 2, tip.dx, tip.dy)
        ..quadraticBezierTo(base.dx + 8, (base.dy + tip.dy) / 2, base.dx + 5, base.dy)
        ..close();
      inked(c, vine, hex(0x4faf35), outline: 2.4);
    }
  },
  'ability_arrow_storm': (c) {
    final cloud = Path()
      ..addOval(const Rect.fromLTWH(14, 12, 48, 34))
      ..addOval(const Rect.fromLTWH(40, 4, 52, 42))
      ..addOval(const Rect.fromLTWH(72, 16, 42, 30));
    inked(c, cloud, hex(0x7d8fb0), outline: 3);
    for (var i = 0; i < 5; i++) {
      final x = 22.0 + i * 21;
      _arrow(c, Offset(x + 10, 46), Offset(x, 112 - (i.isEven ? 0 : 14)), w: 4.4);
    }
  },
  'ability_backflip': (c) {
    final arc = Path()..addArc(Rect.fromCircle(center: _c, radius: 42), -0.3, -4.6);
    c.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = outlineOf(hex(0x4fd4ff)),
    );
    c.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = hex(0x4fd4ff),
    );
    final tip = _c + polar(-0.3, 42);
    inked(c, polygon([tip + const Offset(-14, -18), tip + const Offset(18, -2), tip + const Offset(-6, 18)]), hex(0x4fd4ff), outline: 3);
    for (var i = 0; i < 3; i++) {
      strokeLine(c, Offset(30.0 + i * 10, 112), Offset(42.0 + i * 10, 112), withAlpha(hex(0xffffff), 0.7), 4);
    }
  },
  'ability_potion': (c) => _potion(c, hex(0xe8463c)),
  // --- Interactions --------------------------------------------------------
  'interact_talk': (c) {
    final bubble = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 18, 100, 70), const Radius.circular(26)))
      ..moveTo(36, 84)
      ..lineTo(28, 112)
      ..lineTo(58, 86)
      ..close();
    inked(c, bubble, hex(0xfff6e0), outline: 3.4);
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(40.0 + i * 24, 54), 7, Paint()..color = hex(0x5a4128));
    }
  },
  'interact_mine': (c) {
    inkedLine(c, const Offset(30, 110), const Offset(86, 40), hex(0x9a6436), 9);
    final head = Path()
      ..moveTo(40, 26)
      ..quadraticBezierTo(84, 8, 118, 44)
      ..lineTo(108, 50)
      ..quadraticBezierTo(84, 30, 54, 38)
      ..close();
    inked(c, head, hex(0xb8c2cc), outline: 3, light: 0.4);
    _glow(c, const Offset(26, 30), 18, hex(0xffe9a8), 0.9);
  },
  'interact_gather': (c) {
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + (i - 2) * 0.42;
      final tip = const Offset(64, 108) + polar(a, 80);
      final leaf = Path()
        ..moveTo(64, 108)
        ..quadraticBezierTo(64 + math.cos(a + 0.9) * 40, 108 + math.sin(a + 0.9) * 40, tip.dx, tip.dy)
        ..quadraticBezierTo(64 + math.cos(a - 0.9) * 40, 108 + math.sin(a - 0.9) * 40, 64, 108)
        ..close();
      inked(c, leaf, i.isEven ? hex(0x4fc9a2) : hex(0x3aa37f), outline: 2.6);
    }
  },
  'interact_travel': (c) {
    _glow(c, _c, 60, hex(0x6ff3ff), 0.6);
    final stone = smoothClosed([
      const Offset(44, 116),
      const Offset(38, 60),
      const Offset(54, 10),
      const Offset(76, 12),
      const Offset(90, 62),
      const Offset(84, 116),
    ], tension: 0.3);
    inkedBall(c, stone, hex(0x7f8a99), outline: 3.2);
    final glyph = Path()
      ..moveTo(64, 26)
      ..lineTo(52, 56)
      ..lineTo(76, 70)
      ..lineTo(64, 100)
      ..moveTo(48, 80)
      ..lineTo(80, 80);
    c.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = hex(0x6ff3ff),
    );
  },
  'interact_open': (c) {
    final body = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 56, 96, 56), const Radius.circular(8)));
    inked(c, body, hex(0xa8642e), outline: 3.4);
    final lid = Path()
      ..moveTo(16, 60)
      ..quadraticBezierTo(64, 6, 112, 60)
      ..close();
    inked(c, lid, hex(0xb8703a), outline: 3.4);
    for (final x in [28.0, 92.0]) {
      inkedLine(c, Offset(x, 40), Offset(x, 110), hex(0xe8b84a), 6, outline: 2);
    }
    inked(c, roundRectPath(const Rect.fromLTWH(54, 54, 20, 24), 4), hex(0xffd75e), outline: 2.4);
  },
  // --- Equipment -----------------------------------------------------------
  'item_bow': (c) => _bowShape(c),
  'item_bow_rare': (c) => _bowShape(c, wood: hex(0x5a7fc0), glow: hex(0x4fa3ff)),
  'item_bow_legendary': (c) {
    _bowShape(c, wood: hex(0x6b5a8a), glow: hex(0xffb020));
    final bolt = polygon([
      const Offset(70, 20),
      const Offset(52, 62),
      const Offset(68, 62),
      const Offset(56, 108),
      const Offset(88, 54),
      const Offset(70, 54),
      const Offset(84, 20),
    ]);
    inked(c, bolt, hex(0xfff06a), outline: 2.6, light: 0.3);
  },
  'item_helm': (c) {
    final hood = Path()
      ..moveTo(20, 100)
      ..quadraticBezierTo(16, 20, 64, 16)
      ..quadraticBezierTo(112, 20, 108, 100)
      ..quadraticBezierTo(96, 76, 64, 74)
      ..quadraticBezierTo(32, 76, 20, 100)
      ..close();
    inked(c, hood, hex(0x3f8a3a), outline: 3.4);
    final inner = Path()
      ..moveTo(34, 92)
      ..quadraticBezierTo(36, 44, 64, 40)
      ..quadraticBezierTo(92, 44, 94, 92)
      ..quadraticBezierTo(80, 70, 64, 70)
      ..quadraticBezierTo(46, 70, 34, 92)
      ..close();
    c.drawPath(inner, Paint()..color = hex(0x1d3a1c));
    for (var i = 0; i < 4; i++) {
      inked(c, ellipsePath(Offset(30.0 + i * 22, 104), 9, 12), hex(0x6fcf4a), outline: 2);
    }
  },
  'item_chest': (c) {
    final tunic = Path()
      ..moveTo(36, 16)
      ..lineTo(14, 36)
      ..lineTo(24, 58)
      ..lineTo(34, 52)
      ..lineTo(32, 112)
      ..lineTo(96, 112)
      ..lineTo(94, 52)
      ..lineTo(104, 58)
      ..lineTo(114, 36)
      ..lineTo(92, 16)
      ..quadraticBezierTo(64, 34, 36, 16)
      ..close();
    inked(c, tunic, hex(0x5b8f3a), outline: 3.4);
    inked(c, roundRectPath(const Rect.fromLTWH(32, 76, 64, 12), 3), hex(0x7a4e2b), outline: 2.4, gradient: false);
    inked(c, roundRectPath(const Rect.fromLTWH(56, 74, 16, 16), 3), hex(0xffd36b), outline: 2);
    strokeLine(c, const Offset(52, 26), const Offset(64, 46), hex(0xd9b45a), 4);
    strokeLine(c, const Offset(76, 26), const Offset(64, 46), hex(0xd9b45a), 4);
  },
  'item_gloves': (c) {
    for (final dx in [0.0, 34.0]) {
      final g = Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(18 + dx, 46, 42, 50), const Radius.circular(14)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20 + dx, 88, 38, 22), const Radius.circular(6)));
      inked(c, g, dx == 0 ? hex(0x7a4e2b) : hex(0x8a5a32), outline: 3);
      for (var i = 0; i < 3; i++) {
        inked(c, roundRectPath(Rect.fromLTWH(22 + dx + i * 12, 22, 11, 34), 5), dx == 0 ? hex(0x7a4e2b) : hex(0x8a5a32), outline: 2.6);
      }
    }
  },
  'item_boots': (c) {
    for (final dx in [0.0, 30.0]) {
      final b = Path()
        ..moveTo(26 + dx, 18)
        ..lineTo(58 + dx, 18)
        ..lineTo(58 + dx, 82)
        ..lineTo(84 + dx, 92)
        ..quadraticBezierTo(92 + dx, 108, 76 + dx, 112)
        ..lineTo(24 + dx, 112)
        ..close();
      inked(c, b, dx == 0 ? hex(0x4a3020) : hex(0x5e3d26), outline: 3);
      inked(c, roundRectPath(Rect.fromLTWH(22 + dx, 16, 40, 14), 4), hex(0x6fcf4a), outline: 2.4);
    }
  },
  'item_trinket': (c) {
    final chain = Path()
      ..moveTo(26, 20)
      ..quadraticBezierTo(64, 70, 102, 20);
    c.drawPath(
      chain,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = hex(0xe8b84a),
    );
    _glow(c, const Offset(64, 82), 40, hex(0x4fd4ff), 0.5);
    inked(c, polygon([const Offset(64, 46), const Offset(92, 80), const Offset(64, 116), const Offset(36, 80)]), hex(0x4fd4ff), outline: 3.2, light: 0.45);
    strokeLine(c, const Offset(64, 52), const Offset(64, 110), withAlpha(hex(0xffffff), 0.6), 2);
  },
  'item_fang_necklace': (c) {
    final chain = Path()
      ..moveTo(22, 18)
      ..quadraticBezierTo(64, 74, 106, 18);
    c.drawPath(
      chain,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = hex(0x6b4426),
    );
    _glow(c, const Offset(64, 84), 46, hex(0xffb020), 0.6);
    final fang = Path()
      ..moveTo(46, 50)
      ..quadraticBezierTo(64, 44, 82, 50)
      ..quadraticBezierTo(76, 92, 60, 118)
      ..quadraticBezierTo(56, 84, 46, 50)
      ..close();
    inked(c, fang, hex(0xfff6e0), outline: 3.2, light: 0.3);
  },
  // --- Materials & currency ------------------------------------------------
  'mat_copper_ore': (c) {
    final rock = smoothClosed([
      const Offset(16, 96),
      const Offset(22, 52),
      const Offset(56, 26),
      const Offset(98, 34),
      const Offset(114, 80),
      const Offset(84, 112),
    ], tension: 0.4);
    inkedBall(c, rock, hex(0x8e8a84), outline: 3.4);
    for (final (p, a) in [(const Offset(46, 70), -1.9), (const Offset(70, 56), -1.3), (const Offset(86, 82), -0.9)]) {
      final tip = p + polar(a, 30);
      final n = polar(a + math.pi / 2, 9);
      inked(c, polygon([p - n, tip - n * 0.2, tip + n * 0.2, p + n]), hex(0xe58a3e), outline: 2.4, light: 0.4);
    }
  },
  'mat_sniffleleaf': (c) {
    _glow(c, _c, 56, hex(0x8ff7d0), 0.5);
    final leaf = Path()
      ..moveTo(26, 104)
      ..quadraticBezierTo(14, 34, 100, 18)
      ..quadraticBezierTo(104, 92, 26, 104)
      ..close();
    inked(c, leaf, hex(0x4fc9a2), outline: 3.4);
    strokeLine(c, const Offset(30, 100), const Offset(96, 24), hex(0x2f8a6a), 3);
    for (var i = 1; i < 5; i++) {
      final p = Offset.lerp(const Offset(30, 100), const Offset(96, 24), i / 5)!;
      strokeLine(c, p, p + const Offset(-14, -6), hex(0x2f8a6a), 2);
      strokeLine(c, p, p + const Offset(10, 10), hex(0x2f8a6a), 2);
    }
    for (final p in [const Offset(96, 92), const Offset(108, 76)]) {
      inkedBall(c, ellipsePath(p, 6, 8), hex(0xb9f0ff), outline: 2);
    }
  },
  'mat_goblin_tooth': (c) {
    final tooth = Path()
      ..moveTo(38, 24)
      ..quadraticBezierTo(64, 14, 90, 24)
      ..quadraticBezierTo(96, 50, 84, 64)
      ..quadraticBezierTo(76, 112, 66, 116)
      ..quadraticBezierTo(56, 80, 46, 66)
      ..quadraticBezierTo(30, 48, 38, 24)
      ..close();
    inked(c, tooth, hex(0xf2e6c8), outline: 3.4, light: 0.3);
    c.drawOval(const Rect.fromLTWH(48, 30, 14, 26), Paint()..color = withAlpha(hex(0xffffff), 0.7));
    c.drawOval(const Rect.fromLTWH(70, 36, 10, 10), Paint()..color = withAlpha(hex(0x7dbb3f), 0.6));
  },
  'mat_honey': (c) {
    final pot = Path()
      ..moveTo(42, 30)
      ..quadraticBezierTo(10, 66, 34, 104)
      ..quadraticBezierTo(64, 118, 94, 104)
      ..quadraticBezierTo(118, 66, 86, 30)
      ..close();
    inkedBall(c, pot, hex(0xe0a33a), outline: 3.4);
    inked(c, ellipsePath(const Offset(64, 30), 26, 9), hex(0x8a5a22), outline: 2.6);
    final drip = Path()
      ..moveTo(48, 30)
      ..quadraticBezierTo(44, 60, 54, 66)
      ..quadraticBezierTo(62, 58, 60, 30)
      ..close();
    inked(c, drip, hex(0xffc93c), outline: 2);
  },
  'currency_gold': (c) {
    for (final (p, s) in [(const Offset(44, 84), 1.0), (const Offset(84, 76), 0.9), (const Offset(62, 50), 1.05)]) {
      inked(c, ellipsePath(p + Offset(0, 6 * s), 30 * s, 26 * s), hex(0xc98a1a), outline: 3);
      inkedBall(c, ellipsePath(p, 30 * s, 26 * s), hex(0xffc94f), outline: 3);
      c.drawOval(
        Rect.fromCenter(center: p, width: 30 * s, height: 24 * s),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = hex(0xe0a020),
      );
    }
  },
  'currency_shiny_bits': (c) {
    for (final (p, col) in [(const Offset(40, 80), hex(0xff4bc8)), (const Offset(84, 86), hex(0x4fd4ff)), (const Offset(62, 46), hex(0x82f16d))]) {
      _glow(c, p, 30, col, 0.4);
      inked(c, polygon([p + const Offset(0, -24), p + const Offset(20, -4), p + const Offset(0, 22), p + const Offset(-20, -4)]), col, outline: 3, light: 0.45);
      strokeLine(c, p + const Offset(-20, -4), p + const Offset(20, -4), withAlpha(hex(0xffffff), 0.6), 2);
    }
  },
  'skill_mining': (c) => iconPainters['interact_mine']!(c),
  'skill_herbalism': (c) => iconPainters['interact_gather']!(c),
  'quest_item_wheel': (c) {
    inked(c, circlePath(_c, 50), hex(0x8a5a32), outline: 3.4);
    c.drawCircle(_c, 36, Paint()..color = hex(0x3a2614));
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2;
      inkedLine(c, _c, _c + polar(a, 38), hex(0xb07a45), 6, outline: 1.6);
    }
    inkedBall(c, circlePath(_c, 10), hex(0x8a96a3), outline: 2.4);
  },
  'boss_skull': (c) {
    _glow(c, _c, 60, hex(0xff5b4d), 0.5);
    final skull = smoothClosed([
      const Offset(22, 64),
      const Offset(30, 24),
      const Offset(64, 12),
      const Offset(98, 24),
      const Offset(106, 64),
      const Offset(90, 86),
      const Offset(84, 110),
      const Offset(44, 110),
      const Offset(38, 86),
    ], tension: 0.4);
    inkedBall(c, skull, hex(0xf0e8d6), outline: 3.6);
    c.drawOval(const Rect.fromLTWH(34, 52, 24, 22), Paint()..color = hex(0x221812));
    c.drawOval(const Rect.fromLTWH(70, 52, 24, 22), Paint()..color = hex(0x221812));
    c.drawPath(polygon([const Offset(64, 78), const Offset(56, 92), const Offset(72, 92)]), Paint()..color = hex(0x221812));
  },
};

Future<void> generateIcons(String outDir) async {
  final names = iconPainters.keys.toList();
  final images = <Image>[];
  for (final name in names) {
    final image = await renderImage(_size.toInt(), _size.toInt(), iconPainters[name]!);
    await savePng(image, '$outDir/$name.png');
    images.add(image);
  }
  const cols = 8;
  final rows = (names.length / cols).ceil();
  final sheet = await renderImage(cols * 140, rows * 140, (c) {
    c.drawRect(Rect.fromLTWH(0, 0, cols * 140.0, rows * 140.0), Paint()..color = hex(0x1b2333));
    for (var i = 0; i < images.length; i++) {
      c.drawImage(images[i], Offset((i % cols) * 140.0 + 6, (i ~/ cols) * 140.0 + 6), Paint());
    }
  });
  await savePng(sheet, 'build/art_preview/icons_sheet.png');
}
