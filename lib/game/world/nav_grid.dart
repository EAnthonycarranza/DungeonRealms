import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flame/components.dart';

import 'collision_world.dart';

/// Coarse walkability grid (2 cells per tile) for pathfinding.
class NavGrid {
  NavGrid(this.collision) {
    cols = collision.map.width * cellsPerTile;
    rows = collision.map.height * cellsPerTile;
    rebuild();
  }

  final CollisionWorld collision;
  static const cellsPerTile = 2;
  static const cellSize = 1 / cellsPerTile;
  late final int cols, rows;
  late Uint8List blocked;

  /// Recomputes blocked cells (call after toggling dynamic colliders).
  void rebuild() {
    blocked = Uint8List(cols * rows);
    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final x = (cx + 0.5) * cellSize, y = (cy + 0.5) * cellSize;
        // Agents have ~0.3 radius: keep paths away from obstacle edges.
        blocked[cy * cols + cx] = collision.collides(x, y, 0.22) ? 1 : 0;
      }
    }
  }

  bool isBlocked(int cx, int cy) => cx < 0 || cy < 0 || cx >= cols || cy >= rows || blocked[cy * cols + cx] == 1;

  int cellX(double x) => (x / cellSize).floor();
  int cellY(double y) => (y / cellSize).floor();

  /// Computes a distance field toward [target] limited to [radiusCells].
  FlowField flowTo(Vector2 target, {int radiusCells = 64}) {
    final field = FlowField(this, cellX(target.x), cellY(target.y), radiusCells);
    field._compute();
    return field;
  }
}

/// Dijkstra distance map from one target cell; agents walk downhill.
class FlowField {
  FlowField(this.grid, this.tx, this.ty, this.radius)
    : x0 = math.max(0, tx - radius),
      y0 = math.max(0, ty - radius),
      x1 = math.min(grid.cols - 1, tx + radius),
      y1 = math.min(grid.rows - 1, ty + radius) {
    w = x1 - x0 + 1;
    h = y1 - y0 + 1;
    dist = Float64List(w * h)..fillRange(0, w * h, double.infinity);
  }

  final NavGrid grid;
  final int tx, ty, radius;
  final int x0, y0, x1, y1;
  late final int w, h;
  late final Float64List dist;

  bool _inside(int cx, int cy) => cx >= x0 && cy >= y0 && cx <= x1 && cy <= y1;

  double at(int cx, int cy) => _inside(cx, cy) ? dist[(cy - y0) * w + (cx - x0)] : double.infinity;

  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)];

  void _compute() {
    if (!_inside(tx, ty)) return;
    final heap = _MinHeap();
    dist[(ty - y0) * w + (tx - x0)] = 0;
    heap.push((ty - y0) * w + (tx - x0), 0);
    while (heap.isNotEmpty) {
      final (idx, d) = heap.pop();
      if (d > dist[idx]) continue;
      final cx = idx % w + x0, cy = idx ~/ w + y0;
      for (final (dx, dy) in _dirs) {
        final nx = cx + dx, ny = cy + dy;
        if (!_inside(nx, ny) || grid.isBlocked(nx, ny)) continue;
        final diagonal = dx != 0 && dy != 0;
        if (diagonal && (grid.isBlocked(cx + dx, cy) || grid.isBlocked(cx, cy + dy))) continue;
        final nd = d + (diagonal ? 1.4142 : 1.0);
        final ni = (ny - y0) * w + (nx - x0);
        if (nd < dist[ni]) {
          dist[ni] = nd;
          heap.push(ni, nd);
        }
      }
    }
  }

  /// Unit world direction from [from] toward the target along the field, or
  /// null if [from] is unreachable / outside the field.
  Vector2? direction(Vector2 from, [Vector2? out]) {
    final cx = grid.cellX(from.x), cy = grid.cellY(from.y);
    var best = at(cx, cy);
    if (best.isInfinite) {
      // Standing on a blocked edge cell: look at neighbours.
      best = double.infinity;
    }
    int? bx, by;
    for (final (dx, dy) in _dirs) {
      final d = at(cx + dx, cy + dy);
      if (d < best) {
        best = d;
        bx = cx + dx;
        by = cy + dy;
      }
    }
    if (bx == null || by == null) return null;
    final targetX = (bx + 0.5) * NavGrid.cellSize, targetY = (by + 0.5) * NavGrid.cellSize;
    final o = out ?? Vector2.zero();
    o.setValues(targetX - from.x, targetY - from.y);
    if (o.length2 < 1e-9) return null;
    return o..normalize();
  }
}

class _MinHeap {
  final _idx = <int>[];
  final _pri = <double>[];

  bool get isNotEmpty => _idx.isNotEmpty;

  void push(int i, double p) {
    _idx.add(i);
    _pri.add(p);
    var c = _idx.length - 1;
    while (c > 0) {
      final parent = (c - 1) >> 1;
      if (_pri[parent] <= _pri[c]) break;
      _swap(c, parent);
      c = parent;
    }
  }

  (int, double) pop() {
    final top = (_idx[0], _pri[0]);
    final lastI = _idx.removeLast(), lastP = _pri.removeLast();
    if (_idx.isNotEmpty) {
      _idx[0] = lastI;
      _pri[0] = lastP;
      var c = 0;
      while (true) {
        final l = c * 2 + 1, r = l + 1;
        var m = c;
        if (l < _idx.length && _pri[l] < _pri[m]) m = l;
        if (r < _idx.length && _pri[r] < _pri[m]) m = r;
        if (m == c) break;
        _swap(c, m);
        c = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final ti = _idx[a], tp = _pri[a];
    _idx[a] = _idx[b];
    _pri[a] = _pri[b];
    _idx[b] = ti;
    _pri[b] = tp;
  }
}
