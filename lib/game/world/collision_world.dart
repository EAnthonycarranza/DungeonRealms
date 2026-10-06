import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flame/components.dart';

import 'region_map.dart';

class _Shape {
  _Shape.circle(this.cx, this.cy, this.r, this.tag) : kind = 0, x1 = 0, y1 = 0;
  _Shape.box(double minX, double minY, double maxX, double maxY, this.tag) : kind = 1, cx = minX, cy = minY, x1 = maxX, y1 = maxY, r = 0;
  _Shape.segment(this.cx, this.cy, this.x1, this.y1, this.r, this.tag) : kind = 2;

  final int kind; // 0 circle, 1 box, 2 capsule segment
  final double cx, cy, x1, y1, r;
  final String? tag;

  /// Query stamp so a shape spanning several buckets is visited once.
  int mark = 0;
}

/// Static collision for a region: props (circles, footprints, wall
/// segments) plus impassable terrain sampled on a fine grid.
class CollisionWorld {
  CollisionWorld(this.map) {
    _cols = map.width * cellsPerTile;
    _rows = map.height * cellsPerTile;
    for (final p in [...map.props, ...map.interactives]) {
      _addProp(p);
    }
    _buildTerrain();
  }

  final RegionMap map;
  static const cellsPerTile = 4;
  static const _bucketSize = 2.0;
  late final int _cols, _rows;
  late final Uint8List _terrain;
  final _buckets = <int, List<_Shape>>{};
  final _walkableRects = <(double, double, double, double)>[];
  final _disabledTags = <String>{};

  int _bucketKey(int bx, int by) => bx * 4096 + by;

  void _insert(_Shape s, double minX, double minY, double maxX, double maxY) {
    for (var bx = (minX / _bucketSize).floor(); bx <= (maxX / _bucketSize).floor(); bx++) {
      for (var by = (minY / _bucketSize).floor(); by <= (maxY / _bucketSize).floor(); by++) {
        _buckets.putIfAbsent(_bucketKey(bx, by), () => []).add(s);
      }
    }
  }

  void addCircle(double x, double y, double r, {String? tag}) => _insert(_Shape.circle(x, y, r, tag), x - r, y - r, x + r, y + r);

  void addBox(double minX, double minY, double maxX, double maxY, {String? tag}) => _insert(_Shape.box(minX, minY, maxX, maxY, tag), minX, minY, maxX, maxY);

  void addSegment(double ax, double ay, double bx, double by, double r, {String? tag}) =>
      _insert(_Shape.segment(ax, ay, bx, by, r, tag), math.min(ax, bx) - r, math.min(ay, by) - r, math.max(ax, bx) + r, math.max(ay, by) + r);

  /// Enables/disables shapes with [tag] (e.g. the boss arena gate).
  void setTagEnabled(String tag, bool enabled) => enabled ? _disabledTags.remove(tag) : _disabledTags.add(tag);

  bool isTagEnabled(String tag) => !_disabledTags.contains(tag);

  void _addProp(PlacedTile p) {
    final g = p.ground;
    final info = p.info;
    final tag = p.type == 'boss_gate' ? 'gate:${p.props['boss']}' : null;
    if (info.walkable != null) {
      final w = info.walkable!;
      _walkableRects.add((g.x - w.x / 2, g.y - w.y / 2, g.x + w.x / 2, g.y + w.y / 2));
    }
    if (info.footprint != null) {
      final f = info.footprint!;
      addBox(g.x - f.x / 2, g.y - f.y / 2, g.x + f.x / 2, g.y + f.y / 2, tag: tag);
    }
    if (info.collision > 0) addCircle(g.x, g.y, info.collision, tag: tag);
    if (info.wall != null) {
      final along = info.wall == 'u' ? Vector2(0.55, 0) : Vector2(0, 0.55);
      addSegment(g.x - along.x, g.y - along.y, g.x + along.x, g.y + along.y, 0.14, tag: tag);
    }
  }

  bool _inWalkableOverride(double x, double y) {
    for (final (a, b, c, d) in _walkableRects) {
      if (x >= a && y >= b && x <= c && y <= d) return true;
    }
    return false;
  }

  void _buildTerrain() {
    _terrain = Uint8List(_cols * _rows);
    const step = 1 / cellsPerTile;
    for (var cy = 0; cy < _rows; cy++) {
      for (var cx = 0; cx < _cols; cx++) {
        final x = (cx + 0.5) * step, y = (cy + 0.5) * step;
        final blocked = !map.terrainWalkable(x, y) && !_inWalkableOverride(x, y);
        _terrain[cy * _cols + cx] = blocked ? 1 : 0;
      }
    }
  }

  bool terrainBlockedCell(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= _cols || cy >= _rows) return true;
    return _terrain[cy * _cols + cx] == 1;
  }

  bool terrainBlockedAt(double x, double y) => terrainBlockedCell((x * cellsPerTile).floor(), (y * cellsPerTile).floor());

  /// True if a circle at (x, y) with radius [r] overlaps any static shape or
  /// blocked terrain.
  bool collides(double x, double y, double r) {
    if (_terrainOverlap(x, y, r)) return true;
    var hit = false;
    _visit(x, y, r, (s) {
      if (_shapePush(s, x, y, r) != null) hit = true;
    });
    return hit;
  }

  bool _terrainOverlap(double x, double y, double r) {
    const step = 1 / cellsPerTile;
    for (var cx = ((x - r) * cellsPerTile).floor(); cx <= ((x + r) * cellsPerTile).floor(); cx++) {
      for (var cy = ((y - r) * cellsPerTile).floor(); cy <= ((y + r) * cellsPerTile).floor(); cy++) {
        if (!terrainBlockedCell(cx, cy)) continue;
        final nx = (x.clamp(cx * step, (cx + 1) * step)) - x;
        final ny = (y.clamp(cy * step, (cy + 1) * step)) - y;
        if (nx * nx + ny * ny < r * r) return true;
      }
    }
    return false;
  }

  int _query = 0;

  void _visit(double x, double y, double r, void Function(_Shape) f) {
    final q = ++_query;
    for (var bx = ((x - r) / _bucketSize).floor(); bx <= ((x + r) / _bucketSize).floor(); bx++) {
      for (var by = ((y - r) / _bucketSize).floor(); by <= ((y + r) / _bucketSize).floor(); by++) {
        final list = _buckets[_bucketKey(bx, by)];
        if (list == null) continue;
        for (final s in list) {
          if (s.tag != null && _disabledTags.contains(s.tag)) continue;
          if (s.mark == q) continue;
          s.mark = q;
          f(s);
        }
      }
    }
  }

  /// Push vector (dx, dy) that separates the circle from [s], or null.
  (double, double)? _shapePush(_Shape s, double x, double y, double r) {
    double px, py, rr;
    switch (s.kind) {
      case 0:
        px = s.cx;
        py = s.cy;
        rr = r + s.r;
      case 1:
        px = x.clamp(s.cx, s.x1);
        py = y.clamp(s.cy, s.y1);
        rr = r;
        if (px == x && py == y) {
          // Centre inside the box: push out along the shallowest axis.
          final left = x - s.cx, right = s.x1 - x, top = y - s.cy, bottom = s.y1 - y;
          final m = math.min(math.min(left, right), math.min(top, bottom));
          if (m == left) return (-(left + r), 0);
          if (m == right) return (right + r, 0);
          if (m == top) return (0, -(top + r));
          return (0, bottom + r);
        }
      default:
        final abx = s.x1 - s.cx, aby = s.y1 - s.cy;
        final t = (((x - s.cx) * abx + (y - s.cy) * aby) / (abx * abx + aby * aby)).clamp(0.0, 1.0);
        px = s.cx + abx * t;
        py = s.cy + aby * t;
        rr = r + s.r;
    }
    final dx = x - px, dy = y - py;
    final d2 = dx * dx + dy * dy;
    if (d2 >= rr * rr) return null;
    final d = math.sqrt(d2);
    if (d < 1e-6) return (rr, 0);
    final k = (rr - d) / d;
    return (dx * k, dy * k);
  }

  /// Moves a circle out of all static overlaps. Mutates and returns [pos].
  Vector2 resolve(Vector2 pos, double r) {
    for (var iter = 0; iter < 3; iter++) {
      var moved = false;
      _visit(pos.x, pos.y, r, (s) {
        final push = _shapePush(s, pos.x, pos.y, r);
        if (push != null) {
          pos.x += push.$1;
          pos.y += push.$2;
          moved = true;
        }
      });
      // Terrain cells.
      const step = 1 / cellsPerTile;
      for (var cx = ((pos.x - r) * cellsPerTile).floor(); cx <= ((pos.x + r) * cellsPerTile).floor(); cx++) {
        for (var cy = ((pos.y - r) * cellsPerTile).floor(); cy <= ((pos.y + r) * cellsPerTile).floor(); cy++) {
          if (!terrainBlockedCell(cx, cy)) continue;
          final push = _shapePush(_Shape.box(cx * step, cy * step, (cx + 1) * step, (cy + 1) * step, null), pos.x, pos.y, r);
          if (push != null) {
            pos.x += push.$1;
            pos.y += push.$2;
            moved = true;
          }
        }
      }
      if (!moved) break;
    }
    pos.x = pos.x.clamp(r, map.width - r);
    pos.y = pos.y.clamp(r, map.height - r);
    return pos;
  }

  /// Attempts to move [pos] by [delta] with sliding. Returns the fraction of
  /// the intended distance actually travelled (0..1).
  double move(Vector2 pos, Vector2 delta, double r) {
    final want = delta.length;
    if (want < 1e-9) return 1;
    final start = pos.clone();
    final steps = math.max(1, (want / (r * 0.5)).ceil());
    final stepX = delta.x / steps, stepY = delta.y / steps;
    for (var i = 0; i < steps; i++) {
      pos.x += stepX;
      pos.y += stepY;
      resolve(pos, r);
    }
    return (pos.distanceTo(start) / want).clamp(0.0, 1.0);
  }

  /// Whether the straight line between two points is free of obstacles for
  /// a body of radius [r] (sampled).
  bool clearPath(Vector2 a, Vector2 b, double r) {
    final d = a.distanceTo(b);
    final n = math.max(1, (d / 0.35).ceil());
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      if (collides(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, r)) return false;
    }
    return true;
  }
}
