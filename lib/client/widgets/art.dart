import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../content/hero_defs.dart';

/// Icon from assets/images/icons/.
class IconImage extends StatelessWidget {
  const IconImage(this.id, {super.key, this.size = 32, this.opacity = 1});

  final String id;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Image.asset(
      'assets/images/icons/$id.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    ),
  );
}

/// Loads and caches decoded ui.Images for custom painting.
class ArtCache {
  static final _images = <String, Future<ui.Image>>{};

  static Future<ui.Image> load(String asset) => _images.putIfAbsent(asset, () {
    final completer = Completer<ui.Image>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (e, s) {
        completer.completeError(e, s);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  });
}

/// A circular crop of a hero concept-art sheet (one expression).
class ConceptPortrait extends StatelessWidget {
  const ConceptPortrait({super.key, required this.sheet, required this.crop, this.size = 96, this.ring = const Color(0xffffc94f), this.ringWidth = 3});

  final String sheet;
  final PortraitCrop crop;
  final double size;
  final Color ring;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: ArtCache.load('assets/images/$sheet'),
      builder: (context, snap) => CustomPaint(size: Size.square(size), painter: _PortraitPainter(snap.data, crop, ring, ringWidth)),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.image, this.crop, this.ring, this.ringWidth);

  final ui.Image? image;
  final PortraitCrop crop;
  final Color ring;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    canvas.drawCircle(center, r, Paint()..shader = const RadialGradient(colors: [Color(0xff2a3550), Color(0xff0d1220)]).createShader(Offset.zero & size));
    final img = image;
    if (img != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r - ringWidth / 2)));
      final src = Rect.fromCircle(center: Offset(crop.x, crop.y), radius: crop.radius);
      canvas.drawImageRect(img, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      r - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.image != image || old.crop != crop || old.ring != ring;
}

/// A rectangular crop of a concept sheet (used on hero select cards).
class ConceptSheet extends StatelessWidget {
  const ConceptSheet({super.key, required this.sheet, this.fit = BoxFit.contain});

  final String sheet;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/$sheet', fit: fit, filterQuality: FilterQuality.medium);
}
