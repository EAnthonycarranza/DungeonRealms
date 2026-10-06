import 'dart:math' as math;

import 'package:flame/components.dart';

/// Isometric projection shared by rendering and input.
///
/// Gameplay runs in *world space*: tile units on the ground plane, x along a
/// tile column (screen down-right) and y along a row (screen down-left).
/// Rendering happens in *screen space* pixels, matching flame_tiled's
/// isometric layout for a 128x64 tile map that is [mapHeight] tiles tall.
class Iso {
  Iso({required this.mapWidth, required this.mapHeight, this.tileWidth = 128, this.tileHeight = 64});

  final int mapWidth, mapHeight;
  final double tileWidth, tileHeight;

  double get halfW => tileWidth / 2;
  double get halfH => tileHeight / 2;

  /// World (tile units) -> screen pixels.
  Vector2 toScreen(double wx, double wy, [Vector2? out]) => (out ?? Vector2.zero())..setValues((wx - wy) * halfW + mapHeight * halfW, (wx + wy) * halfH);

  Vector2 toScreenV(Vector2 w, [Vector2? out]) => toScreen(w.x, w.y, out);

  /// Screen pixels -> world (tile units) on the ground plane.
  Vector2 toWorld(double sx, double sy, [Vector2? out]) {
    final a = (sx - mapHeight * halfW) / halfW; // wx - wy
    final b = sy / halfH; // wx + wy
    return (out ?? Vector2.zero())..setValues((a + b) / 2, (b - a) / 2);
  }

  /// Converts a screen-space direction (e.g. joystick, drag) into a unit
  /// world-space direction. Returns zero for a zero input.
  Vector2 screenDirToWorld(double dx, double dy, [Vector2? out]) {
    final wx = dx / halfW + dy / halfH;
    final wy = dy / halfH - dx / halfW;
    final len = math.sqrt(wx * wx + wy * wy);
    final o = out ?? Vector2.zero();
    if (len < 1e-9) return o..setZero();
    return o..setValues(wx / len, wy / len);
  }

  /// Screen-space direction of a world direction (not normalised).
  Vector2 worldDirToScreen(double dx, double dy, [Vector2? out]) => (out ?? Vector2.zero())..setValues((dx - dy) * halfW, (dx + dy) * halfH);

  /// Depth key for sorting: larger is closer to the camera.
  static double depth(double wx, double wy) => wx + wy;

  /// Pixel height of one world unit of vertical "z" (for projectiles, jumps).
  double get zScale => halfH * 1.4;
}
