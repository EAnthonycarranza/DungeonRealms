import 'dart:ui' as ui;

import '../../content/sprite_meta.dart';

/// A loaded character sheet (image + metadata).
class CharacterSheet {
  CharacterSheet(this.meta, this.image);

  final SpriteSheetMeta meta;
  final ui.Image image;

  ui.Rect frameRect(int index) {
    final col = index % meta.columns, row = index ~/ meta.columns;
    return ui.Rect.fromLTWH(col * meta.frameWidth.toDouble(), row * meta.frameHeight.toDouble(), meta.frameWidth.toDouble(), meta.frameHeight.toDouble());
  }

  /// Draws [index] with the feet at the canvas origin.
  void drawFrame(ui.Canvas canvas, int index, {bool flip = false, ui.Paint? paint, double scale = 1}) {
    final s = scale / meta.pixelRatio;
    final dst = ui.Rect.fromLTWH(-meta.anchorX * s, -meta.anchorY * s, meta.frameWidth * s, meta.frameHeight * s);
    if (flip) {
      canvas.save();
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, frameRect(index), dst, paint ?? _defaultPaint);
    if (flip) canvas.restore();
  }

  static final _defaultPaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  /// Approximate on-screen height of the character in world pixels.
  double get visualHeight => meta.visualHeight > 0 ? meta.visualHeight : meta.anchorY / meta.pixelRatio * 0.82;
}

/// Plays animations from a [CharacterSheet].
class SpriteAnimator {
  SpriteAnimator(this.sheet);

  final CharacterSheet sheet;
  String anim = 'idle';
  double time = 0;
  double speed = 1;
  bool back = false;
  bool flip = false;

  SpriteAnimMeta? get _meta => sheet.meta.anim(anim) ?? sheet.meta.anim('idle');

  bool has(String name) => sheet.meta.animations.containsKey(name);

  /// Starts [name] unless it is already playing (or [restart] is set).
  void play(String name, {bool restart = false, double speed = 1}) {
    if (!has(name)) return;
    if (anim == name && !restart) {
      this.speed = speed;
      return;
    }
    anim = name;
    time = 0;
    this.speed = speed;
  }

  void update(double dt) => time += dt * speed;

  /// Duration of the current animation in seconds at speed 1.
  double get duration => _meta?.duration ?? 0.5;

  bool get finished {
    final m = _meta;
    if (m == null || m.loop) return false;
    return time >= m.duration;
  }

  int get frameIndex {
    final m = _meta;
    if (m == null) return 0;
    final facing = back && sheet.meta.hasBackFacing ? 'back' : 'front';
    final (start, count) = m.frames(facing);
    var f = (time * m.fps).floor();
    f = m.loop ? f % count : f.clamp(0, count - 1);
    return start + f;
  }

  void draw(ui.Canvas canvas, {ui.Paint? paint, double scale = 1}) => sheet.drawFrame(canvas, frameIndex, flip: flip, paint: paint, scale: scale);
}
