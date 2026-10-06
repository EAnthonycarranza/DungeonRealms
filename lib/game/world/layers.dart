import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';
import '../entities/entity.dart';
import 'region_map.dart';

/// A static prop image (tree, rock, house...). Not a Component: thousands of
/// these exist, so they are stored in a grid and only drawn when visible.
class PropSprite implements Drawable {
  PropSprite(this.tile, this.image, Vector2 groundScreen)
    : bottom = Offset(groundScreen.x, groundScreen.y + tile.info.anchorY),
      _depth = tile.ground.x + tile.ground.y;

  final PlacedTile tile;
  final Image image;

  /// Screen point of the image's bottom-centre.
  final Offset bottom;
  final double _depth;
  double alpha = 1;
  double targetAlpha = 1;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  double get depth => _depth;

  @override
  Rect get screenBounds =>
      Rect.fromLTWH(bottom.dx - tile.info.width / 2, bottom.dy - tile.info.height, tile.info.width.toDouble(), tile.info.height.toDouble());

  @override
  void draw(Canvas canvas) {
    final topLeft = Offset(bottom.dx - tile.info.width / 2, bottom.dy - tile.info.height);
    if (alpha >= 0.99) {
      canvas.drawImage(image, topLeft, _paint);
    } else {
      canvas.drawImage(
        image,
        topLeft,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }
  }
}

/// Draws props and entities sorted by depth, culled to the camera view.
class EntityLayer extends Component with HasGameReference<DungeonRealmsGame> {
  EntityLayer() : super(priority: 0);

  static const _bucket = 512.0;
  final _buckets = <int, List<PropSprite>>{};
  final _draw = <Drawable>[];
  final visibleEntities = <GameEntity>[];
  int _preparedFrame = -1;
  Rect _view = Rect.zero;

  int _key(int bx, int by) => bx * 65536 + by;

  void addProp(PropSprite p) {
    final b = p.screenBounds;
    for (var bx = (b.left / _bucket).floor(); bx <= (b.right / _bucket).floor(); bx++) {
      for (var by = (b.top / _bucket).floor(); by <= (b.bottom / _bucket).floor(); by++) {
        _buckets.putIfAbsent(_key(bx, by), () => []).add(p);
      }
    }
  }

  /// Visible-set computation, shared by the ground layer (shadows) and this
  /// layer. Runs once per rendered frame.
  void prepareFrame(Rect view) {
    if (_preparedFrame == game.frameCounter) return;
    _preparedFrame = game.frameCounter;
    _view = view;
    _draw.clear();
    visibleEntities.clear();
    final seen = <PropSprite>{};
    for (var bx = (view.left / _bucket).floor(); bx <= (view.right / _bucket).floor(); bx++) {
      for (var by = (view.top / _bucket).floor(); by <= (view.bottom / _bucket).floor(); by++) {
        final list = _buckets[_key(bx, by)];
        if (list == null) continue;
        for (final p in list) {
          if (seen.add(p) && view.overlaps(p.screenBounds)) _draw.add(p);
        }
      }
    }
    for (final c in children) {
      if (c is GameEntity && !c.despawned && view.overlaps(c.screenBounds)) {
        _draw.add(c);
        visibleEntities.add(c);
      }
    }
    _draw.sort((a, b) => a.depth.compareTo(b.depth));
  }

  /// Fades tall props that stand in front of the hero.
  void updateOcclusion(double dt, GameEntity? hero) {
    for (final p in _fading) {
      p.targetAlpha = 1;
    }
    if (hero != null) {
      final heroRect = Rect.fromLTRB(hero.position.x - 26, hero.position.y - 96, hero.position.x + 26, hero.position.y);
      for (var bx = (heroRect.left / _bucket).floor(); bx <= (heroRect.right / _bucket).floor(); bx++) {
        for (var by = (heroRect.top / _bucket).floor(); by <= (heroRect.bottom / _bucket).floor(); by++) {
          for (final p in _buckets[_key(bx, by)] ?? const <PropSprite>[]) {
            if (!p.tile.info.isTall || p.depth <= hero.depth) continue;
            if (p.screenBounds.deflate(18).overlaps(heroRect)) {
              p.targetAlpha = 0.42;
              _fading.add(p);
            }
          }
        }
      }
    }
    final rate = math.min(1.0, dt * 8);
    for (final p in _fading) {
      p.alpha += (p.targetAlpha - p.alpha) * rate;
    }
    _fading.removeWhere((p) {
      final done = p.targetAlpha == 1 && p.alpha > 0.99;
      if (done) p.alpha = 1;
      return done;
    });
  }

  final _fading = <PropSprite>{};

  @override
  void renderTree(Canvas canvas) {
    prepareFrame(game.cameraView());
    for (final d in _draw) {
      d.draw(canvas);
    }
  }

  Rect get view => _view;
}

/// Flat things on the ground: bridges, shadows, telegraphs, area effects.
class GroundLayer extends Component with HasGameReference<DungeonRealmsGame> {
  GroundLayer() : super(priority: -5);

  final groundProps = <PropSprite>[];

  @override
  void render(Canvas canvas) {
    final view = game.cameraView();
    game.entityLayer.prepareFrame(view);
    for (final p in groundProps) {
      if (view.overlaps(p.screenBounds)) p.draw(canvas);
    }
    for (final e in game.entityLayer.visibleEntities) {
      canvas.save();
      canvas.translate(e.position.x, e.position.y);
      e.renderGround(canvas);
      canvas.restore();
    }
  }
}

/// Above everything: combat text, sparks, beams.
class OverlayLayer extends Component {
  OverlayLayer() : super(priority: 10);
}
