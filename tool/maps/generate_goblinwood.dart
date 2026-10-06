// Bootstraps assets/tiles/goblinwood.tmx (Level 1-8 region).
//
//   dart run tool/maps/generate_goblinwood.dart
//
// This is a one-time generator: once the map exists, edit it visually in
// Tiled (https://www.mapeditor.org). Re-running this script OVERWRITES hand
// edits. Layout is described in logical tile coordinates (x right, y down);
// in the isometric view +x points down-right and +y points down-left, so the
// logical top-left corner is the top of the screen.
import 'dart:io';
import 'dart:math' as math;

const W = 76;
const H = 76;
const tileW = 128;
const tileH = 64;

final rng = math.Random(20261006);

// ---------------------------------------------------------------------------
// Tileset parsing
// ---------------------------------------------------------------------------

class TsxTile {
  TsxTile(this.id, this.props, this.width, this.height);
  final int id;
  final Map<String, String> props;
  final int width, height;
}

List<TsxTile> parseTsx(String path) {
  final xml = File(path).readAsStringSync();
  final tiles = <TsxTile>[];
  final tileRe = RegExp(r'<tile id="(\d+)"[^>]*>(.*?)</tile>', dotAll: true);
  final propRe = RegExp(r'<property name="([^"]+)"(?: type="[^"]+")? value="([^"]*)"/>');
  final imgRe = RegExp(r'<image source="[^"]+" width="(\d+)" height="(\d+)"/>');
  for (final m in tileRe.allMatches(xml)) {
    final body = m.group(2)!;
    final props = {for (final p in propRe.allMatches(body)) p.group(1)!: p.group(2)!};
    final img = imgRe.firstMatch(body);
    tiles.add(TsxTile(int.parse(m.group(1)!), props, img == null ? 0 : int.parse(img.group(1)!), img == null ? 0 : int.parse(img.group(2)!)));
  }
  return tiles;
}

// ---------------------------------------------------------------------------
// Noise + shapes
// ---------------------------------------------------------------------------

double _hash(int x, int y, int seed) {
  var h = x * 374761393 + y * 668265263 + seed * 1442695041;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h & 0x7fffffff) / 0x7fffffff;
}

double noise(double x, double y, int seed) {
  final x0 = x.floor(), y0 = y.floor();
  double s(double t) => t * t * (3 - 2 * t);
  final fx = s(x - x0), fy = s(y - y0);
  final a = _hash(x0, y0, seed), b = _hash(x0 + 1, y0, seed);
  final c = _hash(x0, y0 + 1, seed), d = _hash(x0 + 1, y0 + 1, seed);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

double fbm(double x, double y, int seed) => (noise(x, y, seed) * 0.6 + noise(x * 2.1, y * 2.1, seed + 7) * 0.3 + noise(x * 4.3, y * 4.3, seed + 13) * 0.1);

class P {
  const P(this.x, this.y);
  final double x, y;
  P operator +(P o) => P(x + o.x, y + o.y);
  P operator -(P o) => P(x - o.x, y - o.y);
  P operator *(double k) => P(x * k, y * k);
  double get len => math.sqrt(x * x + y * y);
  double dist(P o) => (this - o).len;
}

double distToSegment(P p, P a, P b) {
  final ab = b - a;
  final t = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / (ab.x * ab.x + ab.y * ab.y)).clamp(0.0, 1.0);
  return p.dist(a + ab * t);
}

/// Smooth polyline through control points (Catmull-Rom sampled).
List<P> spline(List<P> pts, {int steps = 8}) {
  final out = <P>[];
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = pts[math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(pts.length - 1, i + 2)];
    for (var s = 0; s < steps; s++) {
      final t = s / steps, t2 = t * t, t3 = t2 * t;
      out.add(
        P(
          0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
          0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
        ),
      );
    }
  }
  out.add(pts.last);
  return out;
}

double distToPolyline(P p, List<P> line) {
  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    best = math.min(best, distToSegment(p, line[i], line[i + 1]));
  }
  return best;
}

class Ellipse {
  const Ellipse(this.c, this.rx, this.ry);
  final P c;
  final double rx, ry;

  /// < 1 inside.
  double value(P p) => math.sqrt(math.pow((p.x - c.x) / rx, 2) + math.pow((p.y - c.y) / ry, 2));
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

// Key places.
const buckleburg = P(58, 60);
const plaza = P(58.5, 60.5);
const crossroads = P(37, 46);
const campCenter = P(41, 19);
const bridgeAt = P(24.6, 41.6);
const arenaCenter = P(14, 13);
const hollowCenter = P(58, 23);
const meadowSW = P(25, 57);
const meadowE = P(50, 38);

final roadMain = spline([const P(53.5, 58.5), const P(48, 55), const P(43, 50.5), crossroads]);
final roadNorth = spline([crossroads, const P(39, 39), const P(40.5, 32), const P(41, 25.5)]);
final roadWest = spline([crossroads, const P(31, 44.2), bridgeAt, const P(19.5, 38.5), const P(16, 32), const P(14.5, 25), const P(14, 20)]);
final trailHollow = spline([const P(40.8, 31), const P(46, 29.5), const P(51, 27), const P(55, 25)]);
final trailMeadow = spline([const P(34, 49), const P(30, 53), const P(26, 56)]);
final stream = spline([
  const P(31, -2),
  const P(29, 8),
  const P(26.5, 18),
  const P(27.5, 28),
  const P(25.5, 37),
  bridgeAt,
  const P(22, 49),
  const P(17.5, 58),
  const P(15, 67),
  const P(13, 78),
]);

final clearings = <Ellipse>[
  const Ellipse(buckleburg, 13, 12),
  const Ellipse(crossroads, 9.5, 8),
  const Ellipse(meadowE, 7, 6.5),
  const Ellipse(campCenter, 12.5, 10.5),
  const Ellipse(P(24, 42), 6.5, 6),
  const Ellipse(P(16, 33), 5.5, 6.5),
  const Ellipse(arenaCenter, 9.5, 9.5),
  const Ellipse(hollowCenter, 7.5, 6.5),
  const Ellipse(meadowSW, 8.5, 6.5),
  const Ellipse(P(47, 51), 6, 4.5),
  const Ellipse(P(30, 30), 4.5, 6),
];

bool isOpen(P p) {
  final n = (fbm(p.x * 0.18, p.y * 0.18, 5) - 0.5) * 0.5;
  for (final e in clearings) {
    if (e.value(p) < 1 + n) return true;
  }
  if (distToPolyline(p, roadMain) < 3.6 + n * 3) return true;
  if (distToPolyline(p, roadNorth) < 3.4 + n * 3) return true;
  if (distToPolyline(p, roadWest) < 3.4 + n * 3) return true;
  if (distToPolyline(p, trailHollow) < 1.6 + n) return true;
  if (distToPolyline(p, trailMeadow) < 2.2 + n * 2) return true;
  if (distToPolyline(p, stream) < 2.4 + n * 2) return true;
  return false;
}

String terrainAtCorner(int i, int j) {
  final p = P(i.toDouble(), j.toDouble());
  // Map border is always deep forest.
  final edge = math.min(math.min(i, j), math.min(W - i, H - j));
  final n = fbm(p.x * 0.3, p.y * 0.3, 11) - 0.5;
  final n2 = fbm(p.x * 0.6, p.y * 0.6, 23) - 0.5;
  if (distToPolyline(p, stream) < 1.25 + n * 0.8) return 'water';
  // Pond near the east meadow.
  if (const Ellipse(P(47.5, 51.5), 3.2, 2.2).value(p) < 1 + n * 0.3) return 'water';
  if (edge <= 4 + n * 3) return 'forest';
  // Buckleburg cobble plaza.
  if (const Ellipse(plaza, 5.6, 5.0).value(p) < 1 + n2 * 0.15) return 'cobble';
  // Roads.
  final road = math.min(math.min(distToPolyline(p, roadMain), distToPolyline(p, roadNorth)), distToPolyline(p, roadWest));
  if (road < 1.0 + n2 * 0.6) return 'dirt';
  // Trampled ground in the goblin camp and Grizzlefang's arena.
  if (Ellipse(campCenter, 7.5, 6.0).value(p) < 1 + n * 0.5) return 'dirt';
  if (Ellipse(arenaCenter, 6.5, 6.5).value(p) < 1 + n * 0.5) return 'dirt';
  // Grizzlefang's hollow is a sealed bowl: forest all around except the road
  // in from the south, which the bramble gate closes during the fight.
  final toArena = p.dist(arenaCenter);
  if (toArena > 8.0 + n * 0.6 && toArena < 12.5 && distToPolyline(p, roadWest) > 2.0 && distToPolyline(p, stream) > 3.0) return 'forest';
  if (!isOpen(p)) return 'forest';
  return 'grass';
}

// ---------------------------------------------------------------------------
// Terrain fixing & tile selection
// ---------------------------------------------------------------------------

const allowedPairs = {'forest|grass', 'dirt|grass', 'grass|water', 'cobble|grass', 'cobble|dirt'};

bool validCorners(Iterable<String> cs) {
  final set = cs.toSet();
  if (set.length == 1) return true;
  if (set.length > 2) return false;
  final l = set.toList()..sort();
  return allowedPairs.contains(l.join('|'));
}

void fixCorners(List<List<String>> corner) {
  for (var pass = 0; pass < 12; pass++) {
    var changed = 0;
    for (var j = 0; j < H; j++) {
      for (var i = 0; i < W; i++) {
        final pts = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)];
        final cs = [for (final (x, y) in pts) corner[x][y]];
        if (validCorners(cs)) continue;
        final set = cs.toSet();
        String from, to;
        if (set.containsAll(['grass', 'dirt', 'cobble']) && set.length == 3) {
          from = 'grass';
          to = 'dirt';
        } else if (set.contains('forest')) {
          from = 'forest';
          to = 'grass';
        } else if (set.contains('water') && set.contains('dirt')) {
          from = 'dirt';
          to = 'grass';
        } else if (set.contains('water') && set.contains('cobble')) {
          from = 'cobble';
          to = 'grass';
        } else {
          // Generic: demote the rarest non-grass terrain to grass.
          final counts = <String, int>{};
          for (final c in cs) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
          final candidates = counts.keys.where((t) => t != 'grass').toList()..sort((a, b) => counts[a]!.compareTo(counts[b]!));
          from = candidates.first;
          to = 'grass';
        }
        for (final (x, y) in pts) {
          if (corner[x][y] == from) {
            corner[x][y] = to;
            changed++;
          }
        }
      }
    }
    if (changed == 0) return;
  }
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

class PlacedObject {
  PlacedObject(this.gid, this.x, this.y, this.w, this.h, {this.type = '', this.name = '', this.props = const {}});
  final int gid;
  final double x, y; // iso pixel coords (Tiled object space)
  final int w, h;
  final String type, name;
  final Map<String, String> props;
}

class World {
  World(this.propTiles, this.propFirstGid) {
    for (final t in propTiles) {
      byName[t.props['name']!] = t;
    }
  }

  final List<TsxTile> propTiles;
  final int propFirstGid;
  final byName = <String, TsxTile>{};
  final props = <PlacedObject>[];
  final interactives = <PlacedObject>[];
  final occupied = <(P, double)>[];
  late List<List<String>> corner;

  String terrainAt(double x, double y) {
    // Majority terrain of the nearest corner.
    final i = x.round().clamp(0, W), j = y.round().clamp(0, H);
    return corner[i][j];
  }

  bool free(P p, double r) {
    for (final (q, qr) in occupied) {
      if (p.dist(q) < r + qr) return false;
    }
    return true;
  }

  /// Places a prop with its ground centre at [p].
  PlacedObject place(
    String name,
    P p, {
    double radius = 0.4,
    String layer = 'props',
    String type = '',
    String objName = '',
    Map<String, String> props = const {},
  }) {
    final t = byName[name] ?? (throw ArgumentError('unknown prop $name'));
    final anchorY = double.parse(t.props['anchorY'] ?? '0');
    // Image bottom = ground centre shifted down-screen by anchorY pixels.
    final wx = p.x + anchorY / tileH;
    final wy = p.y + anchorY / tileH;
    final obj = PlacedObject(propFirstGid + t.id, wx * tileH, wy * tileH, t.width, t.height, type: type, name: objName, props: props);
    (layer == 'props' ? this.props : interactives).add(obj);
    occupied.add((p, radius));
    return obj;
  }
}

/// Poisson-disc style scatter using dart throwing.
List<P> scatter(double minDist, bool Function(P) accept, {int attempts = 30000, double x0 = 0, double y0 = 0, double x1 = W + 0.0, double y1 = H + 0.0}) {
  final pts = <P>[];
  final cell = minDist / math.sqrt2;
  final gw = ((x1 - x0) / cell).ceil() + 1, gh = ((y1 - y0) / cell).ceil() + 1;
  final grid = List<P?>.filled(gw * gh, null);
  for (var a = 0; a < attempts; a++) {
    final p = P(x0 + rng.nextDouble() * (x1 - x0), y0 + rng.nextDouble() * (y1 - y0));
    final gx = ((p.x - x0) / cell).floor(), gy = ((p.y - y0) / cell).floor();
    var ok = true;
    for (var dx = -2; dx <= 2 && ok; dx++) {
      for (var dy = -2; dy <= 2 && ok; dy++) {
        final nx = gx + dx, ny = gy + dy;
        if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
        final q = grid[ny * gw + nx];
        if (q != null && q.dist(p) < minDist) ok = false;
      }
    }
    if (!ok || !accept(p)) continue;
    grid[gy * gw + gx] = p;
    pts.add(p);
  }
  return pts;
}

T pick<T>(List<T> items) => items[rng.nextInt(items.length)];

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final terrainTiles = parseTsx('assets/tiles/terrain.tsx');
  final decorTiles = parseTsx('assets/tiles/decor.tsx');
  final propTiles = parseTsx('assets/tiles/props.tsx');
  const terrainFirst = 1;
  final decorFirst = terrainFirst + terrainTiles.length;
  final propFirst = decorFirst + decorTiles.length;

  // 1. Terrain corners.
  final corner = List.generate(W + 1, (i) => List.generate(H + 1, (j) => terrainAtCorner(i, j)));
  fixCorners(corner);

  // 2. Ground tiles.
  final byCorners = <String, List<TsxTile>>{};
  for (final t in terrainTiles) {
    byCorners.putIfAbsent(t.props['corners']!, () => []).add(t);
  }
  final ground = List.generate(H, (_) => List.filled(W, 0));
  var missing = 0;
  for (var j = 0; j < H; j++) {
    for (var i = 0; i < W; i++) {
      final key = [corner[i][j], corner[i + 1][j], corner[i + 1][j + 1], corner[i][j + 1]].join(',');
      final options = byCorners[key];
      if (options == null) {
        missing++;
        ground[j][i] = terrainFirst; // grass fallback
        continue;
      }
      TsxTile chosen;
      if (options.length == 1) {
        chosen = options.first;
      } else {
        // Variant 0 is the common one.
        chosen = rng.nextDouble() < 0.55 ? options.first : pick(options);
      }
      ground[j][i] = terrainFirst + chosen.id;
    }
  }
  if (missing > 0) stderr.writeln('WARNING: $missing tiles had no matching terrain tile');

  final world = World(propTiles, propFirst)..corner = corner;
  bool fullTile(int i, int j, String t) => corner[i][j] == t && corner[i + 1][j] == t && corner[i + 1][j + 1] == t && corner[i][j + 1] == t;

  // 3. Decor layer.
  final decorIds = {for (final t in decorTiles) t.props['name']!: decorFirst + t.id};
  final decor = List.generate(H, (_) => List.filled(W, 0));
  for (var j = 0; j < H; j++) {
    for (var i = 0; i < W; i++) {
      final r = rng.nextDouble();
      final p = P(i + 0.5, j + 0.5);
      // Each table maps a cumulative chance to a decor tile.
      String? roll(List<(double, String)> table) {
        for (final (chance, name) in table) {
          if (r < chance) return name;
        }
        return null;
      }

      if (fullTile(i, j, 'grass')) {
        final name = roll(const [
          (0.035, 'flowers_yellow'),
          (0.06, 'flowers_pink'),
          (0.085, 'grass_tuft'),
          (0.1, 'clover'),
          (0.108, 'mushroom_ring'),
          (0.118, 'twigs'),
        ]);
        if (name != null) decor[j][i] = decorIds[name]!;
      } else if (fullTile(i, j, 'forest')) {
        final name = roll(const [(0.08, 'leaves'), (0.11, 'moss_stones'), (0.13, 'twigs')]);
        if (name != null) decor[j][i] = decorIds[name]!;
      } else if (fullTile(i, j, 'dirt')) {
        final inCamp = Ellipse(campCenter, 8, 6.5).value(p) < 1;
        final inArena = Ellipse(arenaCenter, 7, 7).value(p) < 1;
        if (inCamp && r < 0.1) decor[j][i] = pick([decorIds['bones']!, decorIds['scorch']!, decorIds['puddle']!]);
        if (inArena && r < 0.16) decor[j][i] = pick([decorIds['bones']!, decorIds['bear_tracks']!, decorIds['scorch']!]);
        if (!inCamp && !inArena && r < 0.04) decor[j][i] = decorIds['pebbles']!;
      }
    }
  }
  // Bear tracks leading into the arena along the west road.
  for (var k = 0; k < 6; k++) {
    final p = roadWest[roadWest.length - 1 - k * 3];
    final i = p.x.floor(), j = p.y.floor();
    if (fullTile(i, j, 'dirt')) decor[j][i] = decorIds['bear_tracks']!;
  }

  // 4. Set pieces (placed before scattered trees so trees avoid them).
  setPieces(world);

  // 5. Forests: dense trees on forest terrain, sparse trees in the open.
  final treeNames = ['tree_oak_1', 'tree_oak_2', 'tree_oak_3', 'tree_pine_1', 'tree_pine_2', 'tree_lime_1', 'tree_autumn_1', 'tree_autumn_2'];
  final denseWeights = [4, 3, 3, 4, 3, 2, 1, 1];
  String weightedTree(List<int> weights) {
    final total = weights.reduce((a, b) => a + b);
    var r = rng.nextInt(total);
    for (var k = 0; k < weights.length; k++) {
      r -= weights[k];
      if (r < 0) return treeNames[k];
    }
    return treeNames.first;
  }

  final dense = scatter(1.55, (p) {
    if (p.x < 0.6 || p.y < 0.6 || p.x > W - 0.6 || p.y > H - 0.6) return false;
    final i = p.x.floor(), j = p.y.floor();
    if (!fullTile(i, j, 'forest')) return false;
    return world.free(p, 0.6);
  });
  for (final p in dense) {
    final name = weightedTree(denseWeights);
    world.place(name, p, radius: 0.5);
  }
  // Forest undergrowth: bushes/mushrooms near forest edges.
  final edgeBits = scatter(2.2, (p) {
    final i = p.x.floor(), j = p.y.floor();
    if (i < 1 || j < 1 || i >= W - 1 || j >= H - 1) return false;
    final t = {corner[i][j], corner[i + 1][j], corner[i + 1][j + 1], corner[i][j + 1]};
    if (!(t.contains('forest') && t.contains('grass'))) return false;
    return world.free(p, 0.7);
  });
  for (final p in edgeBits) {
    final r = rng.nextDouble();
    final name = r < 0.45
        ? pick(['bush_1', 'bush_2'])
        : r < 0.6
        ? 'bush_berry_1'
        : r < 0.72
        ? 'mushroom_cluster_1'
        : r < 0.82
        ? 'rock_small_1'
        : r < 0.9
        ? 'stump_1'
        : pick(['mushroom_giant_red', 'mushroom_giant_purple']);
    world.place(name, p, radius: 0.45);
  }
  // Sparse trees & rocks in open grass, away from roads and set pieces.
  final sparse = scatter(4.5, (p) {
    final i = p.x.floor(), j = p.y.floor();
    if (i < 1 || j < 1 || i >= W - 1 || j >= H - 1) return false;
    if (!fullTile(i, j, 'grass')) return false;
    final road = math.min(math.min(distToPolyline(p, roadMain), distToPolyline(p, roadNorth)), distToPolyline(p, roadWest));
    if (road < 2.8) return false;
    if (distToPolyline(p, trailHollow) < 2.0) return false;
    for (final keep in keepClear) {
      if (keep.value(p) < 1) return false;
    }
    return world.free(p, 1.4);
  });
  for (final p in sparse) {
    final r = rng.nextDouble();
    final name = r < 0.55
        ? weightedTree([3, 2, 3, 1, 1, 3, 2, 2])
        : r < 0.75
        ? pick(['bush_1', 'bush_2', 'bush_berry_1'])
        : r < 0.88
        ? pick(['rock_small_1', 'rock_medium_1'])
        : pick(['stump_1', 'log_1', 'mushroom_cluster_1']);
    world.place(name, p, radius: 0.6);
  }

  // 6. Gameplay objects (spawns, npcs, zones, markers).
  final objects = gameplayObjects();

  // 7. Write TMX.
  writeTmx(ground, decor, world, objects, decorTiles.length, terrainTiles.length);
  stdout.writeln(
    'Wrote assets/tiles/goblinwood.tmx: ${world.props.length} props, ${world.interactives.length} interactives, '
    '${objects.length} gameplay objects',
  );
}

// Areas that scattered props must not clutter.
final keepClear = <Ellipse>[
  const Ellipse(buckleburg, 10.5, 9.5),
  const Ellipse(crossroads, 6.5, 6),
  Ellipse(campCenter, 9.5, 8),
  Ellipse(arenaCenter, 8.5, 8.5),
  const Ellipse(hollowCenter, 4.5, 4),
  const Ellipse(P(24, 42), 4, 4),
];

void setPieces(World w) {
  // --- Buckleburg Gate ------------------------------------------------------
  w.place('house_red', const P(60.5, 52.6), radius: 2.0);
  w.place('house_blue', const P(66.6, 58.5), radius: 2.0);
  w.place('house_smithy', const P(64.5, 66.2), radius: 2.0);
  w.place('house_red', const P(55.5, 67.2), radius: 2.0);
  w.place('well', const P(60.6, 60.4), radius: 0.8);
  w.place('quest_board', const P(55.2, 56.6), radius: 0.6);
  w.place('signpost', const P(52.6, 59.8), radius: 0.4);
  w.place('lamp_post', const P(54.2, 62.8), radius: 0.3);
  w.place('lamp_post', const P(62.8, 56.0), radius: 0.3);
  w.place('crate_stack', const P(63.4, 63.4), radius: 0.5);
  w.place('crate', const P(62.6, 64.3), radius: 0.4);
  w.place('barrel', const P(61.6, 64.9), radius: 0.4);
  w.place('barrel', const P(57.8, 53.6), radius: 0.4);
  w.place('sack', const P(58.6, 53.2), radius: 0.3);
  w.place('haybale', const P(68.0, 62.6), radius: 0.5);
  w.place('haybale', const P(52.4, 65.4), radius: 0.5);
  for (var k = 0; k < 4; k++) {
    w.place('fence_u', P(63.0 + k * 1.0, 50.5), radius: 0.4);
  }
  for (var k = 0; k < 3; k++) {
    w.place('fence_v', P(69.6, 54.0 + k * 1.0), radius: 0.4);
  }
  w.place(
    'waypoint_stone',
    const P(56.4, 61.8),
    radius: 0.9,
    layer: 'interactives',
    type: 'waypoint',
    objName: 'buckleburg_gate',
    props: {'waypoint': 'buckleburg_gate'},
  );
  w.place('herb_sniffleleaf', const P(66.2, 61.0), radius: 0.4, layer: 'interactives', type: 'resource', props: {'node': 'sniffleleaf'});

  // --- Wagon Crossroads (Pip's broken wagon + public event) -----------------
  w.place('wagon_broken', const P(38.8, 44.0), radius: 1.2);
  w.place('crate', const P(40.4, 45.6), radius: 0.4);
  w.place('sack', const P(36.8, 42.8), radius: 0.3);
  w.place('barrel', const P(39.9, 42.4), radius: 0.4);
  w.place('signpost', const P(34.4, 47.6), radius: 0.4);
  w.place(
    'waypoint_stone',
    const P(33.6, 44.0),
    radius: 0.9,
    layer: 'interactives',
    type: 'waypoint',
    objName: 'wagon_crossroads',
    props: {'waypoint': 'wagon_crossroads'},
  );

  // --- Old Plank Bridge -----------------------------------------------------
  final d = roadWest;
  // Orientation: road runs roughly along -x/-y here; pick the bridge axis.
  final idx = d.indexWhere((p) => p.dist(bridgeAt) < 0.6);
  final a = d[math.max(0, idx - 2)], b = d[math.min(d.length - 1, idx + 2)];
  final alongU = (b.x - a.x).abs() > (b.y - a.y).abs();
  w.place(alongU ? 'bridge_u' : 'bridge_v', bridgeAt, radius: 1.2);

  // --- Copper ore outcrops & herbs -----------------------------------------
  final ores = [
    const P(22.8, 55.2),
    const P(25.6, 59.8),
    const P(28.4, 56.0),
    const P(47.6, 35.6),
    const P(19.2, 30.4),
    const P(60.4, 20.6),
    const P(55.6, 26.2),
  ];
  for (final p in ores) {
    w.place('ore_copper', p, radius: 0.8, layer: 'interactives', type: 'resource', props: {'node': 'copper_vein'});
  }
  for (final p in [const P(21.4, 57.4), const P(27.0, 54.2), const P(30.2, 58.8)]) {
    w.place(pick(['rock_medium_1', 'rock_large_1']), p, radius: 0.8);
  }
  final herbs = [
    const P(52.0, 40.2),
    const P(48.6, 41.6),
    const P(51.4, 36.0),
    const P(23.2, 59.0),
    const P(27.4, 52.6),
    const P(31.2, 32.0),
    const P(29.4, 28.4),
    const P(44.8, 49.0),
  ];
  for (final p in herbs) {
    w.place('herb_sniffleleaf', p, radius: 0.4, layer: 'interactives', type: 'resource', props: {'node': 'sniffleleaf'});
  }

  // --- Snagtooth's Camp ------------------------------------------------------
  w.place('goblin_tent_1', const P(36.4, 15.4), radius: 1.3);
  w.place('goblin_tent_2', const P(45.6, 14.8), radius: 1.3);
  w.place('goblin_tent_1', const P(47.0, 22.6), radius: 1.3);
  w.place('goblin_tent_2', const P(34.8, 22.0), radius: 1.3);
  w.place('campfire', const P(41.0, 19.0), radius: 0.7);
  w.place('goblin_cauldron', const P(43.4, 17.4), radius: 0.5);
  w.place('goblin_totem', const P(39.0, 12.6), radius: 0.4);
  w.place('goblin_totem', const P(44.6, 25.6), radius: 0.4);
  w.place('goblin_banner', const P(38.6, 25.4), radius: 0.3);
  w.place('goblin_banner', const P(43.4, 25.0), radius: 0.3);
  w.place('goblin_cage', const P(32.4, 18.8), radius: 0.6);
  w.place('bone_pile', const P(37.6, 19.8), radius: 0.4);
  w.place('crate_stack', const P(48.2, 18.6), radius: 0.5);
  w.place('barrel', const P(47.4, 17.4), radius: 0.4);
  for (var k = 0; k < 3; k++) {
    w.place('spikes_u', P(32.6 + k * 1.15, 26.6), radius: 0.4);
    w.place('spikes_u', P(46.0 + k * 1.15, 27.2), radius: 0.4);
  }
  w.place(
    'waypoint_stone',
    const P(41.4, 29.2),
    radius: 0.9,
    layer: 'interactives',
    type: 'waypoint',
    objName: 'snagtooth_camp',
    props: {'waypoint': 'snagtooth_camp'},
  );

  // --- Suspicious Hollow (hidden) ------------------------------------------
  w.place('ruin_pillar', const P(55.4, 20.6), radius: 0.4);
  w.place('ruin_pillar_broken', const P(60.8, 24.8), radius: 0.4);
  w.place('ruin_pillar_broken', const P(57.0, 19.4), radius: 0.4);
  w.place('mushroom_giant_purple', const P(61.6, 21.8), radius: 0.4);
  w.place('mushroom_giant_red', const P(54.4, 22.6), radius: 0.4);
  w.place(
    'chest_closed',
    const P(58.4, 21.4),
    radius: 0.6,
    layer: 'interactives',
    type: 'chest',
    objName: 'hollow_chest',
    props: {'loot': 'hollow_chest', 'respawn': '0'},
  );

  // --- Grizzlefang's Hollow -------------------------------------------------
  w.place('cave_mouth', const P(10.2, 8.6), radius: 2.2);
  w.place('honey_pot', const P(13.2, 8.2), radius: 0.4);
  w.place('honey_pot', const P(8.2, 12.4), radius: 0.4);
  w.place('bone_pile', const P(17.4, 10.6), radius: 0.4);
  w.place('bone_pile', const P(11.4, 17.2), radius: 0.4);
  w.place('tree_clawed_1', const P(20.6, 8.8), radius: 0.5);
  w.place('tree_dead_1', const P(7.6, 17.8), radius: 0.5);
  w.place('tree_dead_1', const P(19.8, 18.6), radius: 0.5);
  // Ring of boulders around the arena (leaving the southern entrance open).
  for (var k = 0; k < 14; k++) {
    final ang = k / 14 * math.pi * 2;
    final p = P(arenaCenter.x + math.cos(ang) * 8.4, arenaCenter.y + math.sin(ang) * 8.4);
    // Entrance faces the west road (+y side, near x=14).
    final toEntrance = P(14.2, 21.5).dist(p);
    if (toEntrance < 3.2) continue;
    w.place(pick(['rock_large_1', 'rock_large_2', 'rock_medium_1']), p, radius: 0.9);
  }
  // Just outside the forest ring, where the road is wide enough to walk
  // around the stone.
  w.place(
    'waypoint_stone',
    const P(16.6, 27.4),
    radius: 0.9,
    layer: 'interactives',
    type: 'waypoint',
    objName: 'grizzlefang_hollow',
    props: {'waypoint': 'grizzlefang_hollow'},
  );
  // Arena gate brambles (hidden until the fight starts).
  for (var k = -2; k <= 2; k++) {
    w.place('brambles_u', P(14.2 + k * 1.1, 21.6), radius: 0.3, layer: 'interactives', type: 'boss_gate', props: {'boss': 'grizzlefang'});
  }
}

class GameObj {
  GameObj(this.type, this.name, this.x, this.y, {this.w = 0, this.h = 0, this.point = false, this.ellipse = false, this.props = const {}});
  final String type, name;
  final double x, y, w, h;
  final bool point, ellipse;
  final Map<String, String> props;
}

List<GameObj> gameplayObjects() {
  GameObj zone(String type, String name, P c, double w, double h, Map<String, String> props, {bool ellipse = false}) =>
      GameObj(type, name, c.x - w / 2, c.y - h / 2, w: w, h: h, ellipse: ellipse, props: props);
  GameObj point(String type, String name, P c, [Map<String, String> props = const {}]) => GameObj(type, name, c.x, c.y, point: true, props: props);

  return [
    point('player_start', 'start', const P(58.0, 62.4)),
    // NPCs.
    point('npc', 'bramble', const P(57.6, 57.8), {'npc': 'captain_bramble'}),
    point('npc', 'hilda', const P(63.2, 68.4), {'npc': 'hilda_hammerbottom'}),
    point('npc', 'granny', const P(65.0, 60.8), {'npc': 'granny_gristle'}),
    point('npc', 'pip', const P(37.0, 45.6), {'npc': 'pip_puddlefoot'}),
    // Area names shown when entering.
    zone('area', 'Buckleburg Gate', buckleburg, 20, 18, {'title': 'Buckleburg Gate', 'subtitle': 'Last stop before the goblins'}, ellipse: true),
    zone('area', 'Wagon Crossroads', crossroads, 14, 12, {'title': 'Wagon Crossroads', 'subtitle': 'Pip has had better days'}, ellipse: true),
    zone('area', 'Mossy Meadow', meadowSW, 14, 11, {'title': 'Mossy Meadow', 'subtitle': 'The rocks here are suspiciously shiny'}, ellipse: true),
    zone('area', 'Sniffle Glade', meadowE, 11, 10, {'title': 'Sniffle Glade', 'subtitle': 'Achoo.'}, ellipse: true),
    zone('area', 'Old Plank Bridge', const P(24, 42), 9, 9, {'title': 'Old Plank Bridge', 'subtitle': 'Structurally optimistic'}, ellipse: true),
    zone('area', "Snagtooth's Camp", campCenter, 22, 18, {'title': "Snagtooth's Camp", 'subtitle': 'Smells like soup and bad decisions'}, ellipse: true),
    zone('area', 'Suspicious Hollow', hollowCenter, 12, 10, {'title': 'Suspicious Hollow', 'subtitle': 'Nothing to see here. Probably.'}, ellipse: true),
    zone('area', "Grizzlefang's Hollow", arenaCenter, 17, 17, {'title': "Grizzlefang's Hollow", 'subtitle': 'THIS SEEMS BAD'}, ellipse: true),
    // Enemy spawn zones: pack id, level, respawn seconds.
    zone('spawn', 'road_scouts', const P(46.5, 53.5), 4, 3, {'pack': 'goblin_scouts', 'level': '1', 'respawn': '45'}),
    zone('spawn', 'meadow_scouts', const P(27.5, 55.5), 5, 4, {'pack': 'goblin_scouts', 'level': '2', 'respawn': '45'}),
    zone('spawn', 'glade_scouts', const P(50.5, 38.5), 4, 4, {'pack': 'goblin_raiders', 'level': '2', 'respawn': '50'}),
    zone('spawn', 'north_patrol', const P(39.5, 37.0), 4, 4, {'pack': 'goblin_patrol', 'level': '3', 'respawn': '60'}),
    zone('spawn', 'camp_west', const P(34.5, 19.0), 4, 5, {'pack': 'goblin_patrol', 'level': '4', 'respawn': '60'}),
    zone('spawn', 'camp_east', const P(47.5, 20.0), 4, 5, {'pack': 'goblin_ritual', 'level': '4', 'respawn': '60'}),
    zone('spawn', 'camp_gate', const P(41.0, 25.0), 5, 3, {'pack': 'goblin_camp_guard', 'level': '5', 'respawn': '75'}),
    zone('spawn', 'warboss', const P(41.0, 15.5), 3, 2, {'pack': 'warboss_snagtooth', 'level': '6', 'respawn': '240'}),
    zone('spawn', 'bridge_patrol', const P(18.5, 37.5), 4, 4, {'pack': 'goblin_raiders', 'level': '5', 'respawn': '60'}),
    zone('spawn', 'boss_approach', const P(12.5, 33.0), 4, 4, {'pack': 'goblin_ritual', 'level': '6', 'respawn': '75'}),
    zone('spawn', 'hollow_hoarders', const P(57.5, 23.5), 4, 3, {'pack': 'goblin_hoarders', 'level': '5', 'respawn': '120'}),
    zone('spawn', 'stream_patrol', const P(29.5, 30.0), 4, 4, {'pack': 'goblin_scouts', 'level': '4', 'respawn': '60'}),
    // Public event & boss arena.
    zone('event', 'wagon_defense', crossroads, 12, 10, {'event': 'wagon_wheel_wipeout'}, ellipse: true),
    zone('boss_arena', 'grizzlefang', arenaCenter, 14, 14, {'boss': 'grizzlefang', 'level': '8'}, ellipse: true),
    point('boss_spawn', 'grizzlefang', const P(12.6, 11.4), {'boss': 'grizzlefang'}),
    // Quest triggers.
    zone('trigger', 'enter_camp', campCenter, 16, 13, {'discover': 'snagtooth_camp'}, ellipse: true),
    zone('trigger', 'enter_hollow', hollowCenter, 9, 8, {'discover': 'suspicious_hollow'}, ellipse: true),
  ];
}

String fmt(double v) => v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

void writeTmx(List<List<int>> ground, List<List<int>> decor, World world, List<GameObj> objects, int decorCount, int terrainCount) {
  var nextId = 1;
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<map version="1.10" tiledversion="1.11.0" orientation="isometric" renderorder="right-down" '
      'width="$W" height="$H" tilewidth="$tileW" tileheight="$tileH" infinite="0" nextlayerid="8" nextobjectid="NEXT_ID">',
    )
    ..writeln(' <properties>')
    ..writeln('  <property name="region" value="goblinwood"/>')
    ..writeln(' </properties>')
    ..writeln(' <tileset firstgid="1" source="terrain.tsx"/>')
    ..writeln(' <tileset firstgid="${1 + terrainCount}" source="decor.tsx"/>')
    ..writeln(' <tileset firstgid="${1 + terrainCount + decorCount}" source="props.tsx"/>');
  void layer(int id, String name, List<List<int>> data) {
    b
      ..writeln(' <layer id="$id" name="$name" width="$W" height="$H">')
      ..writeln('  <data encoding="csv">');
    for (var j = 0; j < H; j++) {
      b.writeln('${data[j].join(',')}${j < H - 1 ? ',' : ''}');
    }
    b
      ..writeln('</data>')
      ..writeln(' </layer>');
  }

  layer(1, 'ground', ground);
  layer(2, 'decor', decor);

  void tileObjects(int id, String name, List<PlacedObject> objs) {
    b.writeln(' <objectgroup id="$id" name="$name">');
    // Sort by depth so Tiled draws them in a sensible order too.
    final sorted = [...objs]..sort((a, c) => (a.x + a.y).compareTo(c.x + c.y));
    for (final o in sorted) {
      final attrs = StringBuffer('id="${nextId++}"');
      if (o.name.isNotEmpty) attrs.write(' name="${o.name}"');
      if (o.type.isNotEmpty) attrs.write(' type="${o.type}"');
      attrs.write(' gid="${o.gid}" x="${fmt(o.x)}" y="${fmt(o.y)}" width="${o.w}" height="${o.h}"');
      if (o.props.isEmpty) {
        b.writeln('  <object $attrs/>');
      } else {
        b.writeln('  <object $attrs>');
        b.writeln('   <properties>');
        o.props.forEach((k, v) => b.writeln('    <property name="$k" value="$v"/>'));
        b.writeln('   </properties>');
        b.writeln('  </object>');
      }
    }
    b.writeln(' </objectgroup>');
  }

  tileObjects(3, 'props', world.props);
  tileObjects(4, 'interactives', world.interactives);

  b.writeln(' <objectgroup id="5" name="gameplay">');
  for (final o in objects) {
    final attrs =
        'id="${nextId++}" name="${o.name}" type="${o.type}" x="${fmt(o.x * tileH)}" y="${fmt(o.y * tileH)}"'
        '${o.point ? '' : ' width="${fmt(o.w * tileH)}" height="${fmt(o.h * tileH)}"'}';
    b.writeln('  <object $attrs>');
    if (o.props.isNotEmpty) {
      b.writeln('   <properties>');
      o.props.forEach((k, v) => b.writeln('    <property name="$k" value="${v.replaceAll("'", '&apos;').replaceAll('"', '&quot;')}"/>'));
      b.writeln('   </properties>');
    }
    if (o.point) b.writeln('   <point/>');
    if (o.ellipse) b.writeln('   <ellipse/>');
    b.writeln('  </object>');
  }
  b.writeln(' </objectgroup>');
  b.writeln('</map>');
  final xml = b.toString().replaceFirst('NEXT_ID', '$nextId');
  File('assets/tiles/goblinwood.tmx').writeAsStringSync(xml);
}
