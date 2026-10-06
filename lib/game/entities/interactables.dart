import 'dart:math' as math;
import 'dart:ui';

import '../../content/game_data.dart';
import '../world/region_map.dart';
import 'entity.dart';

/// An entity drawn with an image from the props tileset.
abstract class PropBackedEntity extends GameEntity {
  PropBackedEntity(this.placed, this.image) : super(ground: placed.ground.clone(), radius: placed.info.collision) {
    boundsHalfWidth = placed.info.width / 2;
    boundsHeight = placed.info.height - placed.info.anchorY;
  }

  final PlacedTile placed;
  Image image;
  PropTileInfo? imageInfo;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  void drawImage(Canvas canvas, {double alpha = 1}) {
    final info = imageInfo ?? placed.info;
    final dst = Offset(-info.width / 2, info.anchorY - info.height);
    if (alpha >= 0.99) {
      canvas.drawImage(image, dst, _paint);
    } else {
      canvas.drawImage(
        image,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }
  }

  @override
  void render(Canvas canvas) => drawImage(canvas);
}

/// Ore veins and herbs (Day Jobs).
class ResourceNodeEntity extends PropBackedEntity implements Interactable {
  ResourceNodeEntity(super.placed, super.image, {required this.def, required this.depletedImage, required this.depletedInfo}) : _fullImage = image;

  final ResourceDef def;
  final Image _fullImage;
  final Image depletedImage;
  final PropTileInfo depletedInfo;
  bool available = true;
  double respawnTimer = 0;

  @override
  double get interactRange => 1.5;

  @override
  String get promptLabel => def.skill == 'mining' ? 'Mine' : 'Pick';

  @override
  String get promptIcon => def.icon;

  @override
  bool get canInteract => available && game.hero.alive && game.hero.gatherTarget == null;

  @override
  void interact() => game.hero.startGather(this);

  void deplete() {
    available = false;
    respawnTimer = def.respawn;
    image = depletedImage;
    imageInfo = depletedInfo;
  }

  @override
  void update(double dt) {
    if (!available) {
      respawnTimer -= dt;
      if (respawnTimer <= 0) {
        available = true;
        image = _fullImage;
        imageInfo = null;
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (available) {
      // Gentle shimmer so resources read as interactive.
      final pulse = 0.5 + 0.5 * math.sin(game.time * 2.5 + ground.x);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: 70, height: 30), Paint()..color = Color.fromRGBO(255, 230, 150, 0.08 + 0.1 * pulse));
    }
    super.render(canvas);
  }
}

/// One-time treasure chest.
class ChestEntity extends PropBackedEntity implements Interactable {
  ChestEntity(super.placed, super.image, {required this.openImage, required this.openInfo, required this.lootTable, required bool opened}) : _opened = opened {
    if (opened) {
      image = openImage;
      imageInfo = openInfo;
    }
  }

  final Image openImage;
  final PropTileInfo openInfo;
  final String lootTable;
  bool _opened;

  bool get opened => _opened;

  @override
  double get interactRange => 1.6;
  @override
  String get promptLabel => 'Open';
  @override
  String get promptIcon => 'interact_open';
  @override
  bool get canInteract => !_opened && game.hero.alive;

  @override
  void interact() {
    _opened = true;
    image = openImage;
    imageInfo = openInfo;
    game.openChest(this);
  }

  @override
  void render(Canvas canvas) {
    if (!_opened) {
      final pulse = 0.5 + 0.5 * math.sin(game.time * 3);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 90, height: 40), Paint()..color = Color.fromRGBO(255, 215, 94, 0.15 + 0.15 * pulse));
    }
    super.render(canvas);
  }
}

/// Waypoint stone: discover once, then fast-travel from any waypoint.
class WaypointEntity extends PropBackedEntity implements Interactable {
  WaypointEntity(super.placed, super.image, {required this.activeImage, required this.waypointId, required this.waypointName, required this.discovered}) {
    if (discovered) image = activeImage;
  }

  final Image activeImage;
  final String waypointId;
  final String waypointName;
  bool discovered;

  @override
  double get interactRange => 1.8;
  @override
  String get promptLabel => discovered ? 'Travel' : 'Attune';
  @override
  String get promptIcon => 'interact_travel';
  @override
  bool get canInteract => game.hero.alive;

  @override
  void interact() {
    if (!discovered) {
      discovered = true;
      image = activeImage;
      game.discoverWaypoint(this);
    } else {
      game.openWaypointPicker(this);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (discovered) {
      final pulse = 0.5 + 0.5 * math.sin(game.time * 2);
      canvas.drawCircle(const Offset(0, -96), 30 + pulse * 6, Paint()..color = Color.fromRGBO(111, 243, 255, 0.10 + 0.08 * pulse));
    }
  }
}

/// Brambles that seal a boss arena while the fight is on.
class BossGateEntity extends PropBackedEntity {
  BossGateEntity(super.placed, super.image, {required this.bossId});

  final String bossId;
  bool closed = false;
  double _anim = 0;

  @override
  void update(double dt) {
    _anim = closed ? math.min(1, _anim + dt * 3) : math.max(0, _anim - dt * 2);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_anim <= 0.01) return;
    canvas.save();
    canvas.translate(0, (1 - _anim) * 30);
    drawImage(canvas, alpha: _anim);
    canvas.restore();
  }
}
