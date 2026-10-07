// App icons for Android, iOS and the web shell, plus the launch-screen logo.
//
// One emblem (a gold shield with the Ranger's nocked bow and arrow) drawn in
// a 1024×1024 design space, rendered at every size the platforms ask for.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, Path, Rect;

import 'common.dart';

const _ink = Color(0xff1a1208);

/// Android launcher densities: legacy icon size and adaptive layer size (px).
const _androidDensities = {'mdpi': (48, 108), 'hdpi': (72, 162), 'xhdpi': (96, 216), 'xxhdpi': (144, 324), 'xxxhdpi': (192, 432)};

Future<void> generateAppIcons(String root) async {
  // Android: legacy icons (rounded square) and adaptive icon layers.
  final res = '$root/android/app/src/main/res';
  for (final MapEntry(key: density, value: (legacy, adaptive)) in _androidDensities.entries) {
    await savePng(await _render(legacy, (c) => _roundedIcon(c)), '$res/mipmap-$density/ic_launcher.png');
    // Adaptive icons: the system masks a 108dp square; only the centre 66dp is
    // guaranteed visible, so the emblem is drawn smaller on its own layer.
    await savePng(await _render(adaptive, (c) => _emblem(c, scale: 0.8)), '$res/mipmap-$density/ic_launcher_foreground.png');
    await savePngOpaque(await _render(adaptive, _background), '$res/mipmap-$density/ic_launcher_background.png');
  }

  // iOS: every size listed in the asset catalog, opaque (App Store rule).
  final iconSet = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final contents = jsonDecode(File('$iconSet/Contents.json').readAsStringSync()) as Map<String, Object?>;
  final done = <String>{};
  for (final entry in (contents['images']! as List).cast<Map<String, Object?>>()) {
    final file = entry['filename']! as String;
    if (!done.add(file)) continue;
    final points = double.parse((entry['size']! as String).split('x').first);
    final scale = double.parse((entry['scale']! as String).replaceAll('x', ''));
    await savePngOpaque(await _render((points * scale).round(), _fullIcon), '$iconSet/$file');
  }

  // iOS launch screen logo (transparent, centred on the dark storyboard).
  final launch = '$root/ios/Runner/Assets.xcassets/LaunchImage.imageset';
  for (final (suffix, size) in const [('', 200), ('@2x', 400), ('@3x', 600)]) {
    await savePng(await _render(size, (c) => _emblem(c, scale: 0.95)), '$launch/LaunchImage$suffix.png');
  }

  // Web shell (development builds).
  await savePng(await _render(32, (c) => _roundedIcon(c)), '$root/web/favicon.png');
  for (final size in const [192, 512]) {
    await savePng(await _render(size, (c) => _roundedIcon(c)), '$root/web/icons/Icon-$size.png');
    await savePngOpaque(
      await _render(size, (c) {
        _background(c);
        _emblem(c, scale: 0.82);
      }),
      '$root/web/icons/Icon-maskable-$size.png',
    );
  }

  // Contact sheet for eyeballing.
  final full = await _render(360, _fullIcon);
  final rounded = await _render(240, (c) => _roundedIcon(c));
  final adaptiveFg = await _render(240, (c) {
    _background(c);
    _emblem(c, scale: 0.82);
    // The guaranteed-visible circle of an adaptive icon.
    c.drawCircle(
      const Offset(512, 512),
      313,
      Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x88ffffff),
    );
  });
  final small = await _render(48, (c) => _roundedIcon(c));
  final preview = await renderImage(1100, 400, (c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 1100, 400), Paint()..color = const Color(0xff2a2f3a));
    c.drawImage(full, const Offset(20, 20), Paint());
    c.drawImage(rounded, const Offset(400, 20), Paint());
    c.drawImage(adaptiveFg, const Offset(660, 20), Paint());
    c.drawImage(small, const Offset(920, 20), Paint());
  });
  await savePng(preview, 'build/art_preview/app_icons.png');
}

/// Renders the 1024-unit design at [size] pixels.
Future<ui.Image> _render(int size, void Function(Canvas c) draw) => renderImage(size, size, (c) {
  c.scale(size / 1024);
  draw(c);
});

/// Full-bleed square icon (iOS masks the corners itself).
void _fullIcon(Canvas c) {
  _background(c);
  _emblem(c, scale: 1.22);
}

/// Rounded-square icon with transparent corners (legacy Android, web).
void _roundedIcon(Canvas c) {
  c.save();
  c.clipPath(roundRectPath(const Rect.fromLTWH(24, 24, 976, 976), 210));
  _background(c);
  _emblem(c, scale: 1.12);
  c.restore();
}

void _background(Canvas c) {
  const full = Rect.fromLTWH(0, 0, 1024, 1024);
  c.drawRect(
    full,
    Paint()..shader = ui.Gradient.radial(const Offset(512, 360), 780, const [Color(0xff2f4f82), Color(0xff172540), Color(0xff0a0e18)], const [0.0, 0.55, 1.0]),
  );
  // Warm glow behind the emblem.
  c.drawRect(full, Paint()..shader = ui.Gradient.radial(const Offset(512, 560), 430, const [Color(0x55ffb347), Color(0x00ffb347)]));
  // A few faint stars.
  final rng = math.Random(7);
  for (var i = 0; i < 26; i++) {
    final p = Offset(40 + rng.nextDouble() * 944, 40 + rng.nextDouble() * 944);
    if ((p - const Offset(512, 520)).distance < 360) continue;
    c.drawCircle(p, 3 + rng.nextDouble() * 4, Paint()..color = Color.fromRGBO(255, 236, 180, 0.25 + rng.nextDouble() * 0.35));
  }
}

/// The shield emblem, centred in the 1024 space. [scale] 1 is about 600 units tall.
void _emblem(Canvas c, {double scale = 1}) {
  c.save();
  c.translate(512, 520);
  c.scale(scale);

  // Drop shadow.
  c.drawPath(
    _shield(1.0).shift(const Offset(0, 22)),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18),
  );
  // Gold rim and green field.
  c.drawPath(
    _shield(1.0),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-240, -300),
        const Offset(240, 300),
        const [Color(0xfffff1b0), Color(0xffffc94f), Color(0xffe07a1f)],
        const [0.0, 0.45, 1.0],
      ),
  );
  _stroke(c, _shield(1.0), _ink, 18);
  final field = _shield(0.8);
  c.drawPath(
    field,
    Paint()..shader = ui.Gradient.radial(const Offset(-60, -90), 330, const [Color(0xff4fb46c), Color(0xff23683a), Color(0xff123d22)], const [0.0, 0.55, 1.0]),
  );
  _stroke(c, field, _ink, 9);
  // Rim shine on the upper left.
  c.save();
  c.clipRect(const Rect.fromLTRB(-300, -320, 0, 40));
  _stroke(c, _shield(0.92), const Color(0x66ffffff), 7);
  c.restore();
  for (final p in const [Offset(-205, -222), Offset(205, -222), Offset(0, 262)]) {
    inkedBall(c, circlePath(p, 15), const Color(0xffffe08a), outline: 6, outlineColor: _ink);
  }

  _bowAndArrow(c);

  // Sparkles: loot is coming.
  _sparkle(c, const Offset(250, -292), 40);
  _sparkle(c, const Offset(-292, -150), 24);
  _sparkle(c, const Offset(286, 120), 20);
  c.restore();
}

Path _shield(double k) => Path()
  ..moveTo(-235 * k, -250 * k)
  ..quadraticBezierTo(0, -300 * k, 235 * k, -250 * k)
  ..lineTo(235 * k, -40 * k)
  ..cubicTo(235 * k, 130 * k, 120 * k, 230 * k, 0, 300 * k)
  ..cubicTo(-120 * k, 230 * k, -235 * k, 130 * k, -235 * k, -40 * k)
  ..close();

void _stroke(Canvas c, Path p, Color color, double width) => c.drawPath(
  p,
  Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = ui.StrokeJoin.round
    ..color = color,
);

void _bowAndArrow(Canvas c) {
  // The bow runs top-left to bottom-right and bulges toward the arrow's aim.
  const a = Offset(-230, -230), b = Offset(230, 230), control = Offset(170, -170);
  final limb = Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
  Paint limbPaint(Color color, double width) => Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = width
    ..color = color;
  // String first, so the limb overlaps its ends.
  strokeLine(c, a, b, _ink, 13);
  strokeLine(c, a, b, const Color(0xfffff6d8), 6);
  c.drawPath(limb, limbPaint(_ink, 52));
  c.drawPath(limb, limbPaint(const Color(0xff7a4a24), 34));
  c.drawPath(limb, limbPaint(const Color(0xffb27a45), 11));
  for (final tip in [a, b]) {
    inkedBall(c, circlePath(tip, 17), const Color(0xffffc94f), outline: 7, outlineColor: _ink);
  }

  // Arrow along y = -x, nocked on the string and resting on the grip.
  const dir = Offset(0.7071, -0.7071), side = Offset(0.7071, 0.7071);
  const tail = Offset(-195, 195), head = Offset(205, -205);
  strokeLine(c, tail, head, _ink, 42);
  strokeLine(c, tail, head, const Color(0xffd9a066), 25);
  // Grip wrap where the arrow crosses the bow (the limb's midpoint).
  const grip = Offset(85, -85);
  strokeLine(c, grip - side * 34, grip + side * 34, _ink, 60);
  strokeLine(c, grip - side * 34, grip + side * 34, const Color(0xffffc94f), 42);
  for (final k in const [-14.0, 14.0]) {
    strokeLine(c, grip + side * k - dir * 21, grip + side * k + dir * 21, const Color(0xffb8741f), 7);
  }
  // Head.
  final point = head + dir * 112;
  final headPath = polygon([point, head + side * 50 - dir * 8, head + dir * 22, head - side * 50 - dir * 8]);
  c.drawPath(headPath, Paint()..shader = ui.Gradient.linear(head - side * 50, point, const [Color(0xffeef4ff), Color(0xff9aa8b8)]));
  _stroke(c, headPath, _ink, 9);
  // Fletching.
  for (final s in const [1.0, -1.0]) {
    final base = tail + dir * 10;
    final feather = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo((base + side * 78 * s + dir * 36).dx, (base + side * 78 * s + dir * 36).dy, (base + dir * 135).dx, (base + dir * 135).dy)
      ..quadraticBezierTo((base + side * 22 * s + dir * 70).dx, (base + side * 22 * s + dir * 70).dy, base.dx, base.dy)
      ..close();
    inked(c, feather, s > 0 ? const Color(0xff82f16d) : const Color(0xff4faf35), outline: 8, outlineColor: _ink);
  }
  inkedBall(c, circlePath(tail, 14), const Color(0xffffc94f), outline: 6, outlineColor: _ink);
}

void _sparkle(Canvas c, Offset at, double r) {
  final star = Path()
    ..moveTo(at.dx, at.dy - r)
    ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
    ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
    ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
    ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
    ..close();
  c.drawCircle(at, r * 0.9, Paint()..shader = ui.Gradient.radial(at, r * 0.9, const [Color(0x88fff1b0), Color(0x00fff1b0)]));
  c.drawPath(star, Paint()..color = const Color(0xfffff8dc));
  _stroke(c, star, const Color(0xaa3a2400), 3);
}
