// Generates the isometric ground tileset used by every Goblinwood-style map.
//
// Tiles are 128x64 diamonds. Each tile is described by the terrain at its
// four corners (top, right, bottom, left vertex = Tiled's TL, TR, BR, BL
// logical corners). Textures are periodic in tile space, so any two tiles
// that share an edge with matching corner terrains line up seamlessly. The
// tileset also carries a Tiled corner "wangset" so the Terrain brush in Tiled
// paints transitions automatically.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Offset, Paint, PaintingStyle, Rect;

import 'common.dart';

const tileW = 128;
const tileH = 64;
const columns = 8;

/// Terrain ids. Order matters: it is the Tiled wang color index (1-based).
const terrains = ['grass', 'forest', 'dirt', 'water', 'cobble'];
const terrainColors = {'grass': '#5fb544', 'forest': '#2f6b2c', 'dirt': '#c4935a', 'water': '#36a9d0', 'cobble': '#a8a194'};

/// Terrain pairs that have transition tiles. Any other pair must be
/// separated by at least one corner of a shared terrain.
const pairs = [
  ['grass', 'forest'],
  ['grass', 'dirt'],
  ['grass', 'water'],
  ['grass', 'cobble'],
  ['dirt', 'cobble'],
];

const fullVariants = {'grass': 6, 'forest': 3, 'dirt': 3, 'water': 3, 'cobble': 3};

class TileSpec {
  TileSpec(this.corners, this.variant);

  /// Terrain names at TL(top), TR(right), BR(bottom), BL(left).
  final List<String> corners;
  final int variant;

  bool get isFull => corners.toSet().length == 1;
}

List<TileSpec> buildTileSpecs() {
  final specs = <TileSpec>[];
  fullVariants.forEach((t, n) {
    for (var v = 0; v < n; v++) {
      specs.add(TileSpec([t, t, t, t], v));
    }
  });
  for (final pair in pairs) {
    for (var mask = 1; mask < 15; mask++) {
      specs.add(TileSpec([for (var bit = 0; bit < 4; bit++) (mask >> bit) & 1 == 1 ? pair[1] : pair[0]], 0));
    }
  }
  return specs;
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

final _grassDark = hex(0x3f8f2f);
final _grassMid = hex(0x58ad3c);
final _grassLight = hex(0x74c64e);
final _forestDark = hex(0x24552a);
final _forestLight = hex(0x3d7a35);
final _leafBrown = hex(0x8a6232);
final _leafOrange = hex(0xc0802e);
final _dirtDark = hex(0x9a6c3e);
final _dirtMid = hex(0xbb8b54);
final _dirtLight = hex(0xd3a76c);
final _waterDeep = hex(0x2373b0);
final _waterMid = hex(0x2f9dcc);
final _waterShallow = hex(0x5fd0de);
final _foam = hex(0xe9fbff);
final _stoneA = hex(0xb7b0a2);
final _stoneB = hex(0xa0998b);
final _stoneC = hex(0xc9c2b2);
final _mortar = hex(0x6c665c);

// ---------------------------------------------------------------------------
// Field helpers
// ---------------------------------------------------------------------------

/// Converts a pixel position inside a tile image to logical (u, v).
Offset pixelToUv(double px, double py) {
  final a = (px - tileW / 2) / (tileW / 2); // u - v
  final b = py / (tileH / 2); // u + v
  return Offset((a + b) / 2, (b - a) / 2);
}

/// Screen-space offset (pixels) of a logical delta.
Offset uvDeltaToScreen(double du, double dv) => Offset((du - dv) * tileW / 2, (du + dv) * tileH / 2);

double _bilinear(List<double> c, double u, double v) {
  final uu = u.clamp(0.0, 1.0), vv = v.clamp(0.0, 1.0);
  return c[0] * (1 - uu) * (1 - vv) + c[1] * uu * (1 - vv) + c[2] * uu * vv + c[3] * (1 - uu) * vv;
}

/// Boundary wobble, periodic so edges between tiles agree.
double _wobble(double u, double v) => (periodicFbm(u, v, 77, baseCells: 2, octaves: 3) - 0.5) * 0.55;

class _Feature {
  _Feature(this.u, this.v, this.size, this.kind, this.tone, this.lean);
  final double u, v, size, lean;
  final int kind;
  final double tone;
}

/// Periodic feature sets bucketed in an 8x8 grid for fast lookup.
class _FeatureSet {
  _FeatureSet(int count, int seed, double minSize, double maxSize) {
    final rng = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final f = _Feature(
        rng.nextDouble(),
        rng.nextDouble(),
        minSize + rng.nextDouble() * (maxSize - minSize),
        rng.nextInt(3),
        rng.nextDouble(),
        rng.nextDouble() * 2 - 1,
      );
      buckets[(f.u * 8).floor() * 8 + (f.v * 8).floor()].add(f);
    }
  }

  final buckets = List.generate(64, (_) => <_Feature>[]);

  /// Calls [visit] with every feature (and its periodic offset) whose
  /// bucket is within one cell of (u, v).
  void near(double u, double v, void Function(_Feature f, double fu, double fv) visit) {
    final cu = (u * 8).floor(), cv = (v * 8).floor();
    for (var du = -2; du <= 2; du++) {
      for (var dv = -2; dv <= 2; dv++) {
        final bu = cu + du, bv = cv + dv;
        final wu = ((bu % 8) + 8) % 8, wv = ((bv % 8) + 8) % 8;
        final offU = ((bu - wu) / 8).roundToDouble();
        final offV = ((bv - wv) / 8).roundToDouble();
        for (final f in buckets[wu * 8 + wv]) {
          visit(f, f.u + offU, f.v + offV);
        }
      }
    }
  }
}

final _blades = _FeatureSet(230, 1, 4, 8);
final _pebbles = _FeatureSet(18, 2, 1.4, 3.0);
final _leaves = _FeatureSet(38, 3, 1.6, 2.8);
final _sparkles = _FeatureSet(12, 4, 3, 6);

// ---------------------------------------------------------------------------
// Base textures (per sample)
// ---------------------------------------------------------------------------

Color _grassBase(double u, double v) {
  final n = periodicFbm(u, v, 11, baseCells: 2, octaves: 4);
  final m = periodicFbm(u, v, 31, baseCells: 4, octaves: 2);
  var c = n < 0.5 ? mix(_grassDark, _grassMid, n * 2) : mix(_grassMid, _grassLight, (n - 0.5) * 2);
  c = mix(c, shade(c, 0.08), m * 0.6);
  return c;
}

Color _forestBase(double u, double v) {
  final n = periodicFbm(u, v, 13, baseCells: 2, octaves: 4);
  final moss = periodicFbm(u, v, 43, baseCells: 4, octaves: 3);
  var c = mix(_forestDark, _forestLight, n);
  if (moss > 0.62) c = mix(c, hex(0x4f8f3a), (moss - 0.62) * 2.2);
  if (moss < 0.32) c = mix(c, hex(0x4a3a22), (0.32 - moss) * 1.6);
  return c;
}

Color _dirtBase(double u, double v) {
  final n = periodicFbm(u, v, 17, baseCells: 2, octaves: 4);
  final ruts = periodicFbm(u, v, 57, baseCells: 8, octaves: 2);
  var c = n < 0.5 ? mix(_dirtDark, _dirtMid, n * 2) : mix(_dirtMid, _dirtLight, (n - 0.5) * 2);
  if (ruts > 0.66) c = shade(c, -0.08);
  return c;
}

Color _waterBase(double u, double v, double depth) {
  final n = periodicFbm(u, v, 19, baseCells: 2, octaves: 3);
  final ripple = math.sin((u * 2 + v * 2) * math.pi * 4 + n * 6) * 0.5 + 0.5;
  final d = depth.clamp(0.0, 1.0);
  var c = d < 0.5 ? mix(_waterShallow, _waterMid, d * 2) : mix(_waterMid, _waterDeep, (d - 0.5) * 2);
  c = mix(c, shade(c, 0.1), ripple * 0.35 * (0.3 + n));
  return c;
}

/// Periodic cobble pattern (jittered grid Voronoi in u,v space).
Color _cobbleBase(double u, double v) {
  const cells = 4;
  final x = u * cells, y = v * cells;
  final cx = x.floor(), cy = y.floor();
  var d1 = 9.0, d2 = 9.0;
  var bestId = 0;
  var bestDelta = Offset.zero;
  for (var i = -1; i <= 1; i++) {
    for (var j = -1; j <= 1; j++) {
      final gx = cx + i, gy = cy + j;
      final wx = ((gx % cells) + cells) % cells, wy = ((gy % cells) + cells) % cells;
      final px = gx + 0.2 + hash01(wx, wy, 5) * 0.6;
      final py = gy + 0.2 + hash01(wx, wy, 6) * 0.6;
      final dx = x - px, dy = y - py;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < d1) {
        d2 = d1;
        d1 = d;
        bestId = wx * 31 + wy;
        bestDelta = Offset(dx, dy);
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  final edge = d2 - d1;
  final tone = hash01(bestId, 1, 9);
  var stone = tone < 0.33 ? _stoneA : (tone < 0.66 ? _stoneB : _stoneC);
  final grain = periodicFbm(u, v, 61, baseCells: 8, octaves: 2);
  stone = mix(stone, shade(stone, -0.12), grain * 0.5);
  // Light from the top-left: highlight stone sides facing up-left.
  final lit = (-bestDelta.dx - bestDelta.dy) * 0.5;
  stone = shade(stone, (lit * 0.22).clamp(-0.18, 0.16));
  if (edge < 0.06) return _mortar;
  if (edge < 0.11) return mix(_mortar, shade(stone, -0.18), (edge - 0.06) / 0.05);
  return stone;
}

Color _baseColor(String t, double u, double v, double depth) {
  switch (t) {
    case 'grass':
      return _grassBase(u, v);
    case 'forest':
      return _forestBase(u, v);
    case 'dirt':
      return _dirtBase(u, v);
    case 'water':
      return _waterBase(u, v, depth);
    case 'cobble':
      return _cobbleBase(u, v);
  }
  throw ArgumentError(t);
}

// ---------------------------------------------------------------------------
// Tile rendering
// ---------------------------------------------------------------------------

class _TileField {
  _TileField(this.spec) {
    final names = spec.corners.toSet().toList();
    a = names.first;
    b = names.length > 1 ? names[1] : names.first;
    // Order the pair so that "a" is the first terrain listed in [pairs].
    for (final p in pairs) {
      if (p.contains(a) && p.contains(b) && a != b) {
        a = p[0];
        b = p[1];
      }
    }
    weights = [for (final c in spec.corners) c == b && a != b ? 1.0 : 0.0];
    if (a == b) weights = [0, 0, 0, 0];
  }

  final TileSpec spec;
  late String a, b;
  late List<double> weights;

  /// Value above 0.5 means terrain [b].
  double field(double u, double v) {
    if (a == b) return 0;
    return _bilinear(weights, u, v) + _wobble(u, v);
  }

  String terrainAt(double u, double v) => field(u, v) > 0.5 ? b : a;
}

Future<ui.Image> renderTile(TileSpec spec) async {
  final field = _TileField(spec);
  final px = Uint8List(tileW * tileH * 4);
  const ss = 3;
  const margin = 0.016;
  for (var y = 0; y < tileH; y++) {
    for (var x = 0; x < tileW; x++) {
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final uv = pixelToUv(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss);
          final u = uv.dx, v = uv.dy;
          if (u < -margin || v < -margin || u > 1 + margin || v > 1 + margin) continue;
          final c = _sampleColor(field, u, v);
          r += c.r;
          g += c.g;
          b += c.b;
          a += 1;
        }
      }
      if (a == 0) continue;
      var color = Color.from(alpha: 1, red: r / a, green: g / a, blue: b / a);
      final uv = pixelToUv(x + 0.5, y + 0.5);
      color = _features(field, uv.dx, uv.dy, color);
      // dart:ui treats raw RGBA as premultiplied alpha.
      final alpha = a / (ss * ss);
      final i = (y * tileW + x) * 4;
      px[i] = (color.r * alpha * 255).round().clamp(0, 255);
      px[i + 1] = (color.g * alpha * 255).round().clamp(0, 255);
      px[i + 2] = (color.b * alpha * 255).round().clamp(0, 255);
      px[i + 3] = (alpha * 255).round().clamp(0, 255);
    }
  }
  var image = await imageFromRgba(px, tileW, tileH);
  if (spec.isFull) image = await _decorateFull(image, spec);
  return image;
}

Color _sampleColor(_TileField field, double u, double v) {
  if (field.a == field.b) {
    final t = field.a;
    return _baseColor(t, u, v, t == 'water' ? 1.0 : 0.0);
  }
  final f = field.field(u, v);
  final inB = f > 0.5;
  final t = inB ? field.b : field.a;
  final pair = '${field.a}-${field.b}';
  switch (pair) {
    case 'grass-water':
      if (inB) {
        final depth = ((f - 0.5) * 2.4).clamp(0.0, 1.0);
        var c = _waterBase(u, v, depth);
        if (f < 0.535) c = mix(_foam, c, (f - 0.5) / 0.035);
        return c;
      } else {
        var c = _grassBase(u, v);
        if (f > 0.44) c = mix(c, hex(0x8c7a46), ((f - 0.44) / 0.06) * 0.75);
        return c;
      }
    case 'grass-dirt':
      if (inB) {
        var c = _dirtBase(u, v);
        if (f < 0.56) c = mix(shade(c, -0.22), c, (f - 0.5) / 0.06);
        return c;
      }
      return _grassBase(u, v);
    case 'grass-forest':
      // Soft blend band.
      final t2 = ((f - 0.4) / 0.2).clamp(0.0, 1.0);
      return mix(_grassBase(u, v), _forestBase(u, v), t2);
    case 'grass-cobble':
    case 'dirt-cobble':
      if (inB) {
        var c = _cobbleBase(u, v);
        if (f < 0.54) c = mix(_mortar, c, (f - 0.5) / 0.04);
        return c;
      }
      final c = _baseColor(field.a, u, v, 0);
      return f > 0.46 ? mix(c, shade(c, -0.25), (f - 0.46) / 0.04) : c;
  }
  return _baseColor(t, u, v, 0);
}

/// Overlays small periodic features (grass blades, pebbles, leaves, sparkles).
Color _features(_TileField field, double u, double v, Color color) {
  var out = color;
  final here = Offset(u, v);
  void featureSet(
    _FeatureSet set,
    String terrain,
    Color Function(Color base, _Feature f, double cover) paint,
    double Function(_Feature f, Offset screenDelta) coverage,
  ) {
    set.near(u, v, (f, fu, fv) {
      if (field.terrainAt(fu, fv) != terrain) return;
      final d = uvDeltaToScreen(here.dx - fu, here.dy - fv);
      final cover = coverage(f, d);
      if (cover > 0) out = paint(out, f, cover);
    });
  }

  // Grass blades: thin vertical strokes rising from their base point.
  double bladeCover(_Feature f, Offset d) {
    final h = f.size;
    if (d.dy > 0.6 || d.dy < -h) return 0;
    final t = (-d.dy / h).clamp(0.0, 1.0);
    final cx = f.lean * 2.2 * t;
    final half = 1.05 * (1 - t) + 0.2;
    final dist = (d.dx - cx).abs();
    return (half + 0.5 - dist).clamp(0.0, 1.0);
  }

  for (final t in ['grass', 'forest']) {
    if (field.a != t && field.b != t) continue;
    featureSet(_blades, t, (base, f, cover) {
      final light = t == 'grass' ? hex(0x8fd864) : hex(0x4f8f3a);
      final dark = t == 'grass' ? hex(0x3a7f2a) : hex(0x1d4423);
      final c = f.kind == 0 ? dark : (f.kind == 1 ? light : shade(light, -0.15));
      return mix(base, c, cover * 0.85);
    }, bladeCover);
  }

  if (field.a == 'forest' || field.b == 'forest') {
    featureSet(
      _leaves,
      'forest',
      (base, f, cover) {
        final c = f.tone < 0.5 ? _leafBrown : _leafOrange;
        return mix(base, c, cover * 0.6);
      },
      (f, d) {
        final rx = f.size * 1.4, ry = f.size * 0.7;
        final e = (d.dx * d.dx) / (rx * rx) + (d.dy * d.dy) / (ry * ry);
        return ((1 - e) * 3).clamp(0.0, 1.0);
      },
    );
  }

  if (field.a == 'dirt' || field.b == 'dirt') {
    featureSet(
      _pebbles,
      'dirt',
      (base, f, cover) {
        final c = f.tone < 0.5 ? hex(0xd6bf96) : hex(0x977f62);
        return mix(base, c, cover * 0.8);
      },
      (f, d) {
        final rx = f.size * 1.2, ry = f.size * 0.8;
        final e = (d.dx * d.dx) / (rx * rx) + (d.dy * d.dy) / (ry * ry);
        return ((1 - e) * 3).clamp(0.0, 1.0);
      },
    );
  }

  if (field.a == 'water' || field.b == 'water') {
    featureSet(_sparkles, 'water', (base, f, cover) => mix(base, hex(0xd8f6ff), cover * 0.7), (f, d) {
      if (field.field(u, v) < 0.62 && field.a != field.b) return 0;
      final rx = f.size, ry = 0.7;
      final e = (d.dx * d.dx) / (rx * rx) + (d.dy * d.dy) / (ry * ry);
      return ((1 - e) * 2).clamp(0.0, 1.0);
    });
  }
  return out;
}

/// Adds interior-only decorations to full tiles so large areas don't look
/// like a repeating stamp. Everything stays well away from the tile edges.
Future<ui.Image> _decorateFull(ui.Image base, TileSpec spec) async {
  final t = spec.corners.first;
  final rng = math.Random(1000 + terrains.indexOf(t) * 50 + spec.variant);
  return renderImage(tileW, tileH, (c) {
    c.drawImage(base, Offset.zero, Paint());
    Offset at(double u, double v) => uvDeltaToScreen(u, v) + const Offset(tileW / 2, 0);

    // Soft interior tint patch (zero at the edges).
    if (spec.variant > 0) {
      final center = at(0.5 + (rng.nextDouble() - 0.5) * 0.2, 0.5 + (rng.nextDouble() - 0.5) * 0.2);
      final tint = rng.nextBool() ? withAlpha(hex(0xffffff), 0.07) : withAlpha(hex(0x000000), 0.07);
      c.drawOval(Rect.fromCenter(center: center, width: 64, height: 30), Paint()..shader = ui.Gradient.radial(center, 32, [tint, withAlpha(tint, 0)]));
    }

    if (t == 'grass') {
      final flowerColors = [hex(0xffe066), hex(0xffffff), hex(0xff8fb1), hex(0xb9a6ff)];
      final kinds = [0, 2, 0, 3, 1, 0];
      final count = [0, 5, 0, 6, 4, 2][spec.variant];
      final color = flowerColors[kinds[spec.variant] % flowerColors.length];
      for (var i = 0; i < count; i++) {
        final p = at(0.22 + rng.nextDouble() * 0.56, 0.22 + rng.nextDouble() * 0.56);
        _flower(c, p, color, rng);
      }
      if (spec.variant == 2) {
        // A darker clover patch.
        for (var i = 0; i < 14; i++) {
          final p = at(0.3 + rng.nextDouble() * 0.4, 0.3 + rng.nextDouble() * 0.4);
          c.drawCircle(p, 1.8, Paint()..color = hex(0x3e8a2c));
          c.drawCircle(p + const Offset(1.4, -0.8), 1.5, Paint()..color = hex(0x4a9a34));
        }
      }
    } else if (t == 'dirt' && spec.variant > 0) {
      for (var i = 0; i < 3 + spec.variant; i++) {
        final p = at(0.25 + rng.nextDouble() * 0.5, 0.25 + rng.nextDouble() * 0.5);
        final r = 2.0 + rng.nextDouble() * 2.5;
        c.drawOval(Rect.fromCenter(center: p + const Offset(0.6, 0.8), width: r * 2.4, height: r * 1.4), Paint()..color = withAlpha(hex(0x5a3d1e), 0.35));
        c.drawOval(Rect.fromCenter(center: p, width: r * 2.4, height: r * 1.4), Paint()..color = hex(0xb7a284));
        c.drawOval(Rect.fromCenter(center: p - const Offset(0.6, 0.6), width: r * 1.2, height: r * 0.6), Paint()..color = hex(0xdccbaa));
      }
    } else if (t == 'forest' && spec.variant > 0) {
      for (var i = 0; i < 2 + spec.variant * 2; i++) {
        final p = at(0.25 + rng.nextDouble() * 0.5, 0.25 + rng.nextDouble() * 0.5);
        c.drawCircle(p, 2.2, Paint()..color = hex(0x6fa33f));
        c.drawCircle(p + const Offset(-1.6, 0.8), 1.6, Paint()..color = hex(0x5b8f37));
      }
    } else if (t == 'water' && spec.variant > 0) {
      for (var i = 0; i < 2 * spec.variant; i++) {
        final p = at(0.25 + rng.nextDouble() * 0.5, 0.25 + rng.nextDouble() * 0.5);
        c.drawOval(
          Rect.fromCenter(center: p, width: 10 + rng.nextDouble() * 8, height: 3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = withAlpha(hex(0xc8f2ff), 0.55),
        );
      }
    } else if (t == 'cobble' && spec.variant > 0) {
      for (var i = 0; i < spec.variant * 2; i++) {
        final p = at(0.25 + rng.nextDouble() * 0.5, 0.25 + rng.nextDouble() * 0.5);
        c.drawOval(Rect.fromCenter(center: p, width: 6, height: 3), Paint()..color = withAlpha(hex(0x5d8a3a), 0.8));
      }
    }
  });
}

void _flower(ui.Canvas c, Offset p, Color color, math.Random rng) {
  c.drawLine(
    p,
    p + const Offset(0, 4),
    Paint()
      ..color = hex(0x3b7d2c)
      ..strokeWidth = 1.1,
  );
  for (var i = 0; i < 5; i++) {
    final a = i / 5 * math.pi * 2;
    c.drawCircle(p + Offset(math.cos(a) * 1.7, math.sin(a) * 1.1), 1.3, Paint()..color = color);
  }
  c.drawCircle(p, 1.0, Paint()..color = hex(0xffb020));
}

// ---------------------------------------------------------------------------
// Tileset assembly
// ---------------------------------------------------------------------------

Future<void> generateTerrain(String outDir) async {
  final specs = buildTileSpecs();
  final rows = (specs.length / columns).ceil();
  final tiles = <ui.Image>[];
  for (final s in specs) {
    tiles.add(await renderTile(s));
  }
  final sheet = await renderImage(columns * tileW, rows * tileH, (c) {
    for (var i = 0; i < tiles.length; i++) {
      c.drawImage(tiles[i], Offset((i % columns) * tileW.toDouble(), (i ~/ columns) * tileH.toDouble()), Paint());
    }
  });
  await savePng(sheet, '$outDir/terrain.png');
  writeText('$outDir/terrain.tsx', _terrainTsx(specs, rows));

  // A preview sheet that lays a few tiles side by side (for eyeballing seams).
  final preview = await _previewSeams(specs, tiles);
  await savePng(preview, 'build/art_preview/terrain_seams.png');
}

String _terrainTsx(List<TileSpec> specs, int rows) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<tileset version="1.10" tiledversion="1.11.0" name="terrain" tilewidth="$tileW" '
      'tileheight="$tileH" tilecount="${specs.length}" columns="$columns" objectalignment="bottom">',
    )
    ..writeln(' <grid orientation="isometric" width="$tileW" height="$tileH"/>')
    ..writeln(' <image source="terrain.png" width="${columns * tileW}" height="${rows * tileH}"/>');
  for (var i = 0; i < specs.length; i++) {
    final s = specs[i];
    b
      ..writeln(' <tile id="$i"${s.isFull ? ' probability="${s.variant == 0 ? 1 : 0.35}"' : ''}>')
      ..writeln('  <properties>')
      ..writeln('   <property name="corners" value="${s.corners.join(',')}"/>')
      ..writeln('  </properties>')
      ..writeln(' </tile>');
  }
  b
    ..writeln(' <wangsets>')
    ..writeln('  <wangset name="Ground" type="corner" tile="0">');
  for (final t in terrains) {
    final firstTile = specs.indexWhere((s) => s.isFull && s.corners.first == t);
    b.writeln('   <wangcolor name="$t" color="${terrainColors[t]}" tile="$firstTile" probability="1"/>');
  }
  for (var i = 0; i < specs.length; i++) {
    final c = specs[i].corners.map((t) => terrains.indexOf(t) + 1).toList();
    // wangid order: top, topright, right, bottomright, bottom, bottomleft, left, topleft
    b.writeln('   <wangtile tileid="$i" wangid="0,${c[1]},0,${c[2]},0,${c[3]},0,${c[0]}"/>');
  }
  b
    ..writeln('  </wangset>')
    ..writeln(' </wangsets>')
    ..writeln('</tileset>');
  return b.toString();
}

Future<ui.Image> _previewSeams(List<TileSpec> specs, List<ui.Image> tiles) async {
  // Builds a small 10x10 isometric patch: a dirt road and a pond in grass.
  const n = 10;
  final corner = List.generate(n + 1, (_) => List.filled(n + 1, 'grass'));
  for (var i = 0; i <= n; i++) {
    corner[i][4] = 'dirt';
    corner[i][5] = 'dirt';
  }
  for (var i = 6; i <= 9; i++) {
    for (var j = 7; j <= 9; j++) {
      corner[i][j] = 'water';
    }
  }
  corner[1][1] = 'cobble';
  corner[1][2] = 'cobble';
  corner[2][1] = 'forest';
  int find(List<String> cs, int salt) {
    final matches = [
      for (var i = 0; i < specs.length; i++)
        if (_listEq(specs[i].corners, cs)) i,
    ];
    if (matches.isEmpty) return 0;
    return matches[salt % matches.length];
  }

  return renderImage(n * tileW + tileW, n * tileH + tileH, (c) {
    c.drawRect(Rect.fromLTWH(0, 0, n * tileW + tileW.toDouble(), n * tileH + tileH.toDouble()), Paint()..color = hex(0x101418));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final cs = [corner[x][y], corner[x + 1][y], corner[x + 1][y + 1], corner[x][y + 1]];
        final id = find(cs, x * 7 + y * 3);
        final ox = (x - y) * tileW / 2 + n * tileW / 2;
        final oy = (x + y) * tileH / 2 + tileH / 2;
        c.drawImage(tiles[id], Offset(ox, oy), Paint());
      }
    }
  });
}

bool _listEq(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
