import 'dart:ui';

import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';

/// Anything the [EntityLayer] draws in depth order.
abstract interface class Drawable {
  /// Larger values are closer to the camera (drawn later).
  double get depth;

  /// Screen-space bounds used for culling.
  Rect get screenBounds;

  void draw(Canvas canvas);
}

/// Base class for everything that lives on the ground plane.
///
/// [ground] is the authoritative position in world tiles. The component's
/// [position] is derived from it every frame (screen pixels), so gameplay
/// code should only ever touch [ground].
abstract class GameEntity extends PositionComponent with HasGameReference<DungeonRealmsGame> implements Drawable {
  GameEntity({Vector2? ground, this.radius = 0.3}) : ground = ground ?? Vector2.zero();

  final Vector2 ground;
  double radius;

  /// Height above the ground in screen pixels (jumps, flying arrows).
  double z = 0;
  double depthBias = 0;

  /// Half-width and height of the on-screen sprite, for culling.
  double boundsHalfWidth = 64;
  double boundsHeight = 140;

  bool despawned = false;

  @override
  double get depth => ground.x + ground.y + depthBias;

  @override
  Rect get screenBounds => Rect.fromLTRB(position.x - boundsHalfWidth, position.y - boundsHeight - z, position.x + boundsHalfWidth, position.y + 24);

  void syncScreenPosition() => game.iso.toScreen(ground.x, ground.y, position);

  @override
  void update(double dt) {
    super.update(dt);
    syncScreenPosition();
  }

  @override
  void onMount() {
    super.onMount();
    syncScreenPosition();
  }

  /// Drawn by the ground layer (under every sprite): shadows, rings...
  /// The canvas origin is the entity's screen position.
  void renderGround(Canvas canvas) {}

  @override
  void draw(Canvas canvas) => renderTree(canvas);

  void despawn() {
    despawned = true;
    removeFromParent();
  }

  double distanceTo(GameEntity other) => ground.distanceTo(other.ground);
}

/// Something the hero can use with the interact button.
abstract interface class Interactable {
  Vector2 get ground;
  double get interactRange;

  /// Short verb shown on the interact button ("Talk", "Mine"...).
  String get promptLabel;

  /// Icon id from assets/images/icons/.
  String get promptIcon;
  bool get canInteract;
  void interact();
}
