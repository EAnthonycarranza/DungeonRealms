import 'json_reader.dart';

/// One animation in a character sheet. Frames are indices into the sheet's
/// flat frame list (left-to-right, top-to-bottom).
class SpriteAnimMeta {
  SpriteAnimMeta.fromJson(this.name, JsonReader j, List<String> facingNames)
    : fps = j.dbl('fps'),
      loop = j.boolOr('loop', true),
      events = {for (final e in j.doubleMap('events').entries) e.key: e.value.toInt()},
      facings = {
        for (final f in facingNames)
          if (j.has(f)) f: (j.doubles(f)[0].toInt(), j.doubles(f)[1].toInt()),
      };

  final String name;
  final double fps;
  final bool loop;
  final Map<String, int> events;

  /// facing -> (first frame, frame count)
  final Map<String, (int, int)> facings;

  (int, int) frames(String facing) => facings[facing] ?? facings.values.first;

  double get duration => (facings.values.first.$2) / fps;
}

class SpriteSheetMeta {
  SpriteSheetMeta.fromJson(this.id, JsonReader j)
    : image = j.str('image'),
      frameWidth = j.integer('frameWidth'),
      frameHeight = j.integer('frameHeight'),
      columns = j.integer('columns'),
      pixelRatio = j.dblOr('pixelRatio', 1),
      anchorX = j.doubles('anchor')[0],
      anchorY = j.doubles('anchor')[1],
      visualHeight = j.dblOr('visualHeight', 0),
      facingNames = j.strings('facings'),
      animations = {} {
    final anims = j.obj('animations');
    for (final name in anims.json.keys) {
      animations[name] = SpriteAnimMeta.fromJson(name, anims.obj(name), facingNames);
    }
  }

  final String id;
  final String image;
  final int frameWidth, frameHeight, columns;

  /// Sheet pixels per world pixel (frames are drawn at frameSize / ratio).
  final double pixelRatio;

  /// Feet position inside a frame, in sheet pixels.
  final double anchorX, anchorY;

  /// Standing height in world pixels (0 = unknown).
  final double visualHeight;
  final List<String> facingNames;
  final Map<String, SpriteAnimMeta> animations;

  bool get hasBackFacing => facingNames.contains('back');

  SpriteAnimMeta? anim(String name) => animations[name];
}
