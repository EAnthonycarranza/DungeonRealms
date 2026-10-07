// Shared helpers for the procedural art generator.
//
// The generator runs inside `flutter test` so it can use dart:ui (the same
// Canvas API the game uses) to draw, and dart:io to write PNG files.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, Path, Rect;

/// Renders [width]x[height] pixels with [draw] and returns the image.
Future<ui.Image> renderImage(int width, int height, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas);
  return recorder.endRecording().toImage(width, height);
}

/// Builds an image from raw RGBA8888 bytes.
Future<ui.Image> imageFromRgba(Uint8List pixels, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(buffer, width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<void> savePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

/// Writes [image] as an 8-bit RGB PNG with no alpha channel. App stores
/// reject app icons that carry alpha, and dart:ui only encodes RGBA. The
/// image must be fully opaque.
Future<void> savePngOpaque(ui.Image image, String path) async {
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  final w = image.width, h = image.height;
  final raw = Uint8List(h * (1 + w * 3));
  var o = 0;
  for (var y = 0; y < h; y++) {
    raw[o++] = 0; // scanline filter: none
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw[o++] = rgba[i];
      raw[o++] = rgba[i + 1];
      raw[o++] = rgba[i + 2];
    }
  }
  final out = BytesBuilder();
  void chunk(String type, List<int> body) {
    final typed = [...ascii.encode(type), ...body];
    out
      ..add((ByteData(4)..setUint32(0, body.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List());
  }

  out.add(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  // Width, height, 8-bit depth, color type 2 (RGB), default compression/filter/interlace.
  chunk(
    'IHDR',
    (ByteData(13)
          ..setUint32(0, w)
          ..setUint32(4, h)
          ..setUint8(8, 8)
          ..setUint8(9, 2))
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', zlib.encode(raw));
  chunk('IEND', const []);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(out.takeBytes());
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

/// Loads a PNG/WebP from disk into a dart:ui image.
Future<ui.Image> loadImage(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void writeText(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

// ---------------------------------------------------------------------------
// Color helpers
// ---------------------------------------------------------------------------

Color hex(int rgb, [double alpha = 1]) => Color(((alpha * 255).round() << 24) | (rgb & 0xffffff));

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Lightens (positive) or darkens (negative) a color while keeping hue.
Color shade(Color c, double amount) {
  if (amount >= 0) return mix(c, const Color(0xffffffff), amount);
  return mix(c, const Color(0xff000000), -amount);
}

Color withAlpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

/// Darkened, slightly saturated outline color for cartoon strokes.
Color outlineOf(Color c) {
  final hsl = _toHsl(c);
  return _fromHsl(hsl[0], math.min(1, hsl[1] * 1.1), hsl[2] * 0.28, 1);
}

List<double> _toHsl(Color c) {
  final r = c.r, g = c.g, b = c.b;
  final maxV = math.max(r, math.max(g, b));
  final minV = math.min(r, math.min(g, b));
  final l = (maxV + minV) / 2;
  if (maxV == minV) return [0, 0, l];
  final d = maxV - minV;
  final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
  double h;
  if (maxV == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (maxV == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return [h / 6, s, l];
}

Color _fromHsl(double h, double s, double l, double a) {
  double hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  if (s == 0) return Color.from(alpha: a, red: l, green: l, blue: l);
  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  return Color.from(alpha: a, red: hue2rgb(p, q, h + 1 / 3), green: hue2rgb(p, q, h), blue: hue2rgb(p, q, h - 1 / 3));
}

// ---------------------------------------------------------------------------
// Noise (periodic so textures tile seamlessly)
// ---------------------------------------------------------------------------

int _hash(int x, int y, int seed) {
  var h = x * 374761393 + y * 668265263 + seed * 1442695041;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return h & 0x7fffffff;
}

/// Deterministic pseudo random value in [0,1) for an integer lattice point.
double hash01(int x, int y, int seed) => _hash(x, y, seed) / 0x7fffffff;

double _smooth(double t) => t * t * (3 - 2 * t);

/// Value noise that repeats every [period] lattice cells.
double periodicValueNoise(double x, double y, int period, int seed) {
  final x0 = x.floor(), y0 = y.floor();
  final fx = _smooth(x - x0), fy = _smooth(y - y0);
  int wrap(int i) => ((i % period) + period) % period;
  final a = hash01(wrap(x0), wrap(y0), seed);
  final b = hash01(wrap(x0 + 1), wrap(y0), seed);
  final c = hash01(wrap(x0), wrap(y0 + 1), seed);
  final d = hash01(wrap(x0 + 1), wrap(y0 + 1), seed);
  return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy;
}

/// Fractal noise in [0,1], periodic with period 1 in u and v.
double periodicFbm(double u, double v, int seed, {int baseCells = 2, int octaves = 4}) {
  var sum = 0.0, amp = 1.0, norm = 0.0;
  var cells = baseCells;
  for (var o = 0; o < octaves; o++) {
    sum += amp * periodicValueNoise(u * cells, v * cells, cells, seed + o * 101);
    norm += amp;
    amp *= 0.5;
    cells *= 2;
  }
  return sum / norm;
}

// ---------------------------------------------------------------------------
// Cartoon drawing helpers
// ---------------------------------------------------------------------------

/// Fills [path] with a top-left lit gradient and strokes a dark outline.
void inked(Canvas canvas, Path path, Color base, {double outline = 2.4, Color? outlineColor, double light = 0.22, double dark = 0.22, bool gradient = true}) {
  final bounds = path.getBounds();
  final paint = Paint()..isAntiAlias = true;
  if (gradient && bounds.width > 0 && bounds.height > 0) {
    paint.shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [shade(base, light), base, shade(base, -dark)], const [0.0, 0.5, 1.0]);
  } else {
    paint.color = base;
  }
  canvas.drawPath(path, paint);
  if (outline > 0) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = outline
        ..strokeJoin = ui.StrokeJoin.round
        ..strokeCap = ui.StrokeCap.round
        ..color = outlineColor ?? outlineOf(base),
    );
  }
}

/// Same as [inked] but with a radial "ball" highlight (good for heads, rocks).
void inkedBall(Canvas canvas, Path path, Color base, {double outline = 2.4, Color? outlineColor, Offset highlight = const Offset(-0.35, -0.4)}) {
  final b = path.getBounds();
  final center = b.center + Offset(highlight.dx * b.width / 2, highlight.dy * b.height / 2);
  final paint = Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.radial(center, math.max(b.width, b.height) * 0.95, [shade(base, 0.28), base, shade(base, -0.3)], const [0.0, 0.45, 1.0]);
  canvas.drawPath(path, paint);
  if (outline > 0) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = outline
        ..strokeJoin = ui.StrokeJoin.round
        ..color = outlineColor ?? outlineOf(base),
    );
  }
}

void strokeLine(Canvas canvas, Offset a, Offset b, Color color, double width, {ui.StrokeCap cap = ui.StrokeCap.round}) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..isAntiAlias = true
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap,
  );
}

/// A line with a dark outline (draws the outline first, then the core).
void inkedLine(Canvas canvas, Offset a, Offset b, Color color, double width, {double outline = 2.2}) {
  strokeLine(canvas, a, b, outlineOf(color), width + outline * 2);
  strokeLine(canvas, a, b, color, width);
}

Path ellipsePath(Offset c, double rx, double ry) => Path()..addOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2));

Path circlePath(Offset c, double r) => ellipsePath(c, r, r);

Path roundRectPath(Rect r, double radius) => Path()..addRRect(ui.RRect.fromRectAndRadius(r, ui.Radius.circular(radius)));

/// A closed smooth blob through [points] (Catmull-Rom converted to cubics).
Path smoothClosed(List<Offset> points, {double tension = 0.5}) {
  final n = points.length;
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = points[(i - 1 + n) % n];
    final p1 = points[i];
    final p2 = points[(i + 1) % n];
    final p3 = points[(i + 2) % n];
    final c1 = p1 + (p2 - p0) * (tension / 3);
    final c2 = p2 - (p3 - p1) * (tension / 3);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// An irregular blob of radius [r] around [c] with [n] lobes.
Path blob(Offset c, double rx, double ry, math.Random rng, {int n = 9, double jitter = 0.18}) {
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i / n * math.pi * 2;
    final k = 1 + (rng.nextDouble() * 2 - 1) * jitter;
    pts.add(c + Offset(math.cos(a) * rx * k, math.sin(a) * ry * k));
  }
  return smoothClosed(pts);
}

Path polygon(List<Offset> pts) => Path()..addPolygon(pts, true);

/// Soft elliptical ground shadow.
void groundShadow(Canvas canvas, Offset c, double rx, double ry, [double a = 0.35]) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, ry / rx);
  canvas.drawCircle(
    Offset.zero,
    rx,
    Paint()..shader = ui.Gradient.radial(Offset.zero, rx, [withAlpha(const Color(0xff000000), a), withAlpha(const Color(0xff000000), 0)], const [0.45, 1.0]),
  );
  canvas.restore();
}

/// Rotates [p] around [origin] by [angle] radians.
Offset rotateAround(Offset p, Offset origin, double angle) {
  final s = math.sin(angle), c = math.cos(angle);
  final d = p - origin;
  return origin + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
}

Offset polar(double angle, double length) => Offset(math.cos(angle) * length, math.sin(angle) * length);
