// Flat ground decorations (a second tile layer painted over the terrain).
import 'dart:math' as math;
import 'dart:ui';

import 'common.dart';
import 'iso.dart';
import 'terrain.dart' show tileH, tileW;

typedef DecorPainter = void Function(Canvas c, Offset center, math.Random rng);

/// Picks a point inside the tile diamond, away from its edges.
Offset _inside(Offset center, math.Random rng, [double spread = 0.32]) =>
    center + iso((rng.nextDouble() * 2 - 1) * spread, (rng.nextDouble() * 2 - 1) * spread);

void _flowers(Canvas c, Offset center, math.Random rng, List<Color> colors) {
  for (var i = 0; i < 14; i++) {
    final p = _inside(center, rng);
    strokeLine(c, p, p + const Offset(0, 5), hex(0x3b7d2c), 1.2);
    final col = colors[rng.nextInt(colors.length)];
    for (var k = 0; k < 5; k++) {
      final a = k / 5 * math.pi * 2;
      c.drawCircle(p + Offset(math.cos(a) * 2, math.sin(a) * 1.3), 1.6, Paint()..color = col);
    }
    c.drawCircle(p, 1.1, Paint()..color = hex(0xffb020));
  }
}

final Map<String, DecorPainter> decorPainters = {
  'flowers_yellow': (c, ctr, rng) => _flowers(c, ctr, rng, [hex(0xffe066), hex(0xfff2a8)]),
  'flowers_pink': (c, ctr, rng) => _flowers(c, ctr, rng, [hex(0xff8fb1), hex(0xc9a6ff), hex(0xffffff)]),
  'mushroom_ring': (c, ctr, rng) {
    for (var i = 0; i < 9; i++) {
      final a = i / 9 * math.pi * 2;
      final p = ctr + Offset(math.cos(a) * 26, math.sin(a) * 12);
      strokeLine(c, p, p + const Offset(0, -5), hex(0xf2e6cf), 2.2);
      final cap = Path()
        ..moveTo(p.dx - 5, p.dy - 4)
        ..quadraticBezierTo(p.dx, p.dy - 12, p.dx + 5, p.dy - 4)
        ..close();
      inked(c, cap, i.isEven ? hex(0xe8463c) : hex(0xf08a3c), outline: 1);
    }
  },
  'pebbles': (c, ctr, rng) {
    for (var i = 0; i < 12; i++) {
      final p = _inside(ctr, rng);
      final r = 1.6 + rng.nextDouble() * 2.6;
      c.drawOval(Rect.fromCenter(center: p + const Offset(0.8, 1), width: r * 2.4, height: r * 1.4), Paint()..color = withAlpha(hex(0x000000), 0.25));
      c.drawOval(Rect.fromCenter(center: p, width: r * 2.4, height: r * 1.4), Paint()..color = hex(0xb9b2a4));
      c.drawOval(Rect.fromCenter(center: p - const Offset(0.6, 0.5), width: r * 1.1, height: r * 0.6), Paint()..color = hex(0xdcd6c8));
    }
  },
  'leaves': (c, ctr, rng) {
    for (var i = 0; i < 22; i++) {
      final p = _inside(ctr, rng, 0.36);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(rng.nextDouble() * math.pi);
      c.drawOval(const Rect.fromLTWH(-4, -1.6, 8, 3.2), Paint()..color = [hex(0xd9822b), hex(0xb85c1c), hex(0xe8b03a)][rng.nextInt(3)]);
      c.restore();
    }
  },
  'grass_tuft': (c, ctr, rng) {
    for (var t = 0; t < 4; t++) {
      final base = _inside(ctr, rng, 0.25);
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2 + (i - 3) * 0.22;
        inkedLine(c, base, base + polar(a, 10 + rng.nextDouble() * 6), i.isEven ? hex(0x6cc04a) : hex(0x4f9e38), 1.6, outline: 0.8);
      }
    }
  },
  'bones': (c, ctr, rng) {
    for (var i = 0; i < 5; i++) {
      final p = _inside(ctr, rng, 0.28);
      final d = polar(rng.nextDouble() * math.pi, 6);
      inkedLine(c, p - d, p + d, hex(0xefe6d2), 2.4, outline: 0.8);
      c.drawCircle(p - d, 2.2, Paint()..color = hex(0xefe6d2));
      c.drawCircle(p + d, 2.2, Paint()..color = hex(0xefe6d2));
    }
  },
  'puddle': (c, ctr, rng) {
    final path = blob(ctr, 34, 14, rng, n: 10, jitter: 0.2);
    c.drawPath(path, Paint()..color = withAlpha(hex(0x5a4128), 0.55));
    c.drawPath(blob(ctr - const Offset(2, 1), 26, 9, rng, n: 9, jitter: 0.2), Paint()..color = withAlpha(hex(0x7fb6c9), 0.7));
    c.drawOval(Rect.fromCenter(center: ctr - const Offset(8, 3), width: 12, height: 3), Paint()..color = withAlpha(hex(0xffffff), 0.6));
  },
  'moss_stones': (c, ctr, rng) {
    for (var i = 0; i < 5; i++) {
      final p = _inside(ctr, rng, 0.26);
      inkedBall(c, ellipsePath(p, 7 + rng.nextDouble() * 4, 4 + rng.nextDouble() * 2), hex(0x9c978c), outline: 1.2);
      c.drawOval(Rect.fromCenter(center: p - const Offset(0, 2), width: 8, height: 3), Paint()..color = hex(0x6fbf4a));
    }
  },
  'twigs': (c, ctr, rng) {
    for (var i = 0; i < 6; i++) {
      final p = _inside(ctr, rng);
      final d = polar(rng.nextDouble() * math.pi, 7 + rng.nextDouble() * 5);
      strokeLine(c, p - d, p + d, hex(0x6b4426), 1.8);
      strokeLine(c, p, p + polar(rng.nextDouble() * math.pi * 2, 4), hex(0x6b4426), 1.2);
    }
  },
  'bear_tracks': (c, ctr, rng) {
    for (var i = 0; i < 4; i++) {
      final p = ctr + iso(-0.3 + i * 0.2, -0.1 + (i.isEven ? 0.12 : -0.08));
      c.drawOval(Rect.fromCenter(center: p, width: 11, height: 6), Paint()..color = withAlpha(hex(0x3a2a18), 0.55));
      for (var k = 0; k < 4; k++) {
        c.drawCircle(p + Offset(-4.5 + k * 3.0, -4.2), 1.4, Paint()..color = withAlpha(hex(0x3a2a18), 0.55));
      }
    }
  },
  'scorch': (c, ctr, rng) {
    c.drawOval(
      Rect.fromCenter(center: ctr, width: 70, height: 30),
      Paint()..shader = Gradient.radial(ctr, 35, [withAlpha(hex(0x1a120c), 0.55), withAlpha(hex(0x1a120c), 0)]),
    );
  },
  'clover': (c, ctr, rng) {
    for (var i = 0; i < 18; i++) {
      final p = _inside(ctr, rng, 0.3);
      for (var k = 0; k < 3; k++) {
        c.drawCircle(p + polar(k / 3 * math.pi * 2 - math.pi / 2, 1.8), 1.7, Paint()..color = hex(0x3f9a30));
      }
    }
  },
};

Future<void> generateDecor(String tilesDir) async {
  const cols = 6;
  final names = decorPainters.keys.toList();
  final rows = (names.length / cols).ceil();
  final sheet = await renderImage(cols * tileW, rows * tileH, (c) {
    for (var i = 0; i < names.length; i++) {
      final center = Offset((i % cols) * tileW + tileW / 2, (i ~/ cols) * tileH + tileH / 2);
      c.save();
      c.clipRect(Rect.fromLTWH((i % cols) * tileW.toDouble(), (i ~/ cols) * tileH.toDouble(), tileW.toDouble(), tileH.toDouble()));
      decorPainters[names[i]]!(c, center, math.Random(i * 13 + 7));
      c.restore();
    }
  });
  await savePng(sheet, '$tilesDir/decor.png');
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<tileset version="1.10" tiledversion="1.11.0" name="decor" tilewidth="$tileW" '
      'tileheight="$tileH" tilecount="${names.length}" columns="$cols" objectalignment="bottom">',
    )
    ..writeln(' <grid orientation="isometric" width="$tileW" height="$tileH"/>')
    ..writeln(' <image source="decor.png" width="${cols * tileW}" height="${rows * tileH}"/>');
  for (var i = 0; i < names.length; i++) {
    b
      ..writeln(' <tile id="$i">')
      ..writeln('  <properties>')
      ..writeln('   <property name="name" value="${names[i]}"/>')
      ..writeln('  </properties>')
      ..writeln(' </tile>');
  }
  b.writeln('</tileset>');
  writeText('$tilesDir/decor.tsx', b.toString());
}
