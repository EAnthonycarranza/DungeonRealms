// Isometric drawing helpers shared by props and decor.
import 'dart:ui';

import 'common.dart';

/// Pixels per world unit along the screen axes for a 128x64 tile.
const isoHalfW = 64.0;
const isoHalfH = 32.0;

/// Screen offset of a world-space delta (u along the tile column axis,
/// v along the row axis, z up in pixels).
Offset iso(double u, double v, [double z = 0]) => Offset((u - v) * isoHalfW, (u + v) * isoHalfH - z);

/// Draws an isometric box centred on [g] (ground centre in image pixels).
///
/// [a] and [b] are half extents along u and v (world units), [h] the height
/// in pixels, raised by [z0].
void isoBox(
  Canvas c,
  Offset g,
  double a,
  double b,
  double h, {
  required Color left,
  required Color right,
  required Color top,
  double z0 = 0,
  double outline = 2,
}) {
  Offset p(double u, double v, double z) => g + iso(u, v, z + z0);
  final leftFace = polygon([p(-a, b, 0), p(a, b, 0), p(a, b, h), p(-a, b, h)]);
  final rightFace = polygon([p(a, b, 0), p(a, -b, 0), p(a, -b, h), p(a, b, h)]);
  final topFace = polygon([p(-a, -b, h), p(a, -b, h), p(a, b, h), p(-a, b, h)]);
  inked(c, leftFace, left, outline: outline, light: 0.06, dark: 0.08);
  inked(c, rightFace, right, outline: outline, light: 0.04, dark: 0.1);
  inked(c, topFace, top, outline: outline, light: 0.08, dark: 0.06);
}

/// Maps face-local coordinates on the front-left (+v) face of a box to the
/// screen. [s] runs 0..1 from the left corner to the front corner, [t] is
/// height in pixels.
Offset leftFacePoint(Offset g, double a, double b, double s, double t, [double z0 = 0]) => g + iso(-a + 2 * a * s, b, t + z0);

/// Same for the front-right (+u) face: [s] runs 0..1 from the front corner to
/// the right corner.
Offset rightFacePoint(Offset g, double a, double b, double s, double t, [double z0 = 0]) => g + iso(a, b - 2 * b * s, t + z0);

/// Quad on the left face spanning [s0..s1] x [t0..t1].
Path leftFaceQuad(Offset g, double a, double b, double s0, double s1, double t0, double t1, [double z0 = 0]) =>
    polygon([leftFacePoint(g, a, b, s0, t0, z0), leftFacePoint(g, a, b, s1, t0, z0), leftFacePoint(g, a, b, s1, t1, z0), leftFacePoint(g, a, b, s0, t1, z0)]);

Path rightFaceQuad(Offset g, double a, double b, double s0, double s1, double t0, double t1, [double z0 = 0]) => polygon([
  rightFacePoint(g, a, b, s0, t0, z0),
  rightFacePoint(g, a, b, s1, t0, z0),
  rightFacePoint(g, a, b, s1, t1, z0),
  rightFacePoint(g, a, b, s0, t1, z0),
]);

/// Gabled roof whose ridge runs along the u axis, sitting on a box with half
/// extents [a], [b] at height [wallH]. [over] extends the eaves.
void gableRoofU(Canvas c, Offset g, double a, double b, double wallH, double roofH, Color color, {double over = 0.18}) {
  final aa = a + over, bb = b + over;
  Offset p(double u, double v, double z) => g + iso(u, v, z);
  // Visible slopes: the +v slope (front-left) and the gable end on +u.
  final ridgeA = p(-aa, 0, wallH + roofH);
  final ridgeB = p(aa, 0, wallH + roofH);
  final frontSlope = polygon([p(-aa, bb, wallH - 6), p(aa, bb, wallH - 6), ridgeB, ridgeA]);
  final backSlope = polygon([p(-aa, -bb, wallH - 6), p(aa, -bb, wallH - 6), ridgeB, ridgeA]);
  final gable = polygon([p(a, b, wallH), p(a, -b, wallH), p(a, 0, wallH + roofH - 4)]);
  inked(c, backSlope, shade(color, -0.25), outline: 2);
  inked(c, gable, hex(0xd8c39c), outline: 2);
  inked(c, frontSlope, color, outline: 2.2);
  // Shingle rows.
  for (var i = 1; i < 5; i++) {
    final t = i / 5;
    final l = Offset.lerp(p(-aa, bb, wallH - 6), ridgeA, t)!;
    final r = Offset.lerp(p(aa, bb, wallH - 6), ridgeB, t)!;
    strokeLine(c, l, r, withAlpha(shade(color, -0.35), 0.55), 1.4);
  }
  strokeLine(c, ridgeA, ridgeB, shade(color, -0.45), 3);
}

/// Gabled roof whose ridge runs along the v axis.
void gableRoofV(Canvas c, Offset g, double a, double b, double wallH, double roofH, Color color, {double over = 0.18}) {
  final aa = a + over, bb = b + over;
  Offset p(double u, double v, double z) => g + iso(u, v, z);
  final ridgeA = p(0, -bb, wallH + roofH);
  final ridgeB = p(0, bb, wallH + roofH);
  final frontSlope = polygon([p(aa, -bb, wallH - 6), p(aa, bb, wallH - 6), ridgeB, ridgeA]);
  final gable = polygon([p(-a, b, wallH), p(a, b, wallH), p(0, b, wallH + roofH - 4)]);
  final backSlope = polygon([p(-aa, -bb, wallH - 6), p(-aa, bb, wallH - 6), ridgeB, ridgeA]);
  inked(c, backSlope, shade(color, -0.25), outline: 2);
  inked(c, gable, hex(0xd8c39c), outline: 2);
  inked(c, frontSlope, shade(color, -0.08), outline: 2.2);
  for (var i = 1; i < 5; i++) {
    final t = i / 5;
    final l = Offset.lerp(p(aa, -bb, wallH - 6), ridgeA, t)!;
    final r = Offset.lerp(p(aa, bb, wallH - 6), ridgeB, t)!;
    strokeLine(c, l, r, withAlpha(shade(color, -0.4), 0.55), 1.4);
  }
  strokeLine(c, ridgeA, ridgeB, shade(color, -0.45), 3);
}
