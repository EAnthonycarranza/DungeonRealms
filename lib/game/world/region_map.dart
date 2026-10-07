import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// Metadata for one tile in the `props` image-collection tileset.
class PropTileInfo {
  PropTileInfo({
    required this.gid,
    required this.name,
    required this.imageSource,
    required this.width,
    required this.height,
    required this.anchorY,
    required this.collision,
    required this.footprint,
    required this.layer,
    required this.wall,
    required this.walkable,
    required this.emitter,
  });

  final int gid;
  final String name;
  final String imageSource;
  final int width, height;

  /// Pixels from the image bottom up to the ground centre.
  final double anchorY;

  /// Collision circle radius in tiles (0 = none).
  final double collision;

  /// Rectangular footprint (world tiles) centred on the ground centre.
  final Vector2? footprint;

  /// `sorted` (default) or `ground` (drawn flat under characters).
  final String layer;

  /// `u` or `v`: a 1-tile wall segment along that world axis.
  final String? wall;

  /// Rectangle (world tiles) that is walkable even over blocked terrain.
  final Vector2? walkable;
  final String? emitter;

  bool get isGroundLayer => layer == 'ground';
  bool get isTall => height > 150;
}

/// A tile object (prop or interactive) placed on the map.
class PlacedTile {
  PlacedTile(this.info, this.ground, this.type, this.name, this.props);

  final PropTileInfo info;

  /// Ground centre in world tiles.
  final Vector2 ground;
  final String type;
  final String name;
  final Map<String, String> props;
}

/// A non-tile gameplay object (points, zones) in world tiles.
class MapObject {
  MapObject({
    required this.type,
    required this.name,
    required this.position,
    required this.size,
    required this.isPoint,
    required this.isEllipse,
    required this.props,
  });

  final String type;
  final String name;

  /// Top-left for rectangles/ellipses, the point itself for points.
  final Vector2 position;
  final Vector2 size;
  final bool isPoint;
  final bool isEllipse;
  final Map<String, String> props;

  Vector2 get center => isPoint ? position.clone() : position + size / 2;

  bool contains(Vector2 p) {
    if (isPoint) return false;
    if (isEllipse) {
      final c = center;
      final dx = (p.x - c.x) / (size.x / 2), dy = (p.y - c.y) / (size.y / 2);
      return dx * dx + dy * dy <= 1;
    }
    return p.x >= position.x && p.y >= position.y && p.x <= position.x + size.x && p.y <= position.y + size.y;
  }

  /// Uniform random point inside the shape.
  Vector2 randomPoint(math.Random rng) {
    if (isPoint) return position.clone();
    for (var i = 0; i < 20; i++) {
      final p = position + Vector2(rng.nextDouble() * size.x, rng.nextDouble() * size.y);
      if (contains(p)) return p;
    }
    return center;
  }

  String? prop(String key) => props[key];
}

/// Parsed, gameplay-friendly view of a Tiled region map.
class RegionMap {
  RegionMap(this.tiled, {required this.blockedTerrains}) {
    width = tiled.width;
    height = tiled.height;
    tileHeight = tiled.tileHeight.toDouble();
    _parseTilesets();
    _buildCorners();
    _parseObjects();
  }

  final TiledMap tiled;

  /// Terrain types that block movement (from world.json).
  final Set<String> blockedTerrains;
  late final int width, height;
  late final double tileHeight;

  /// Terrain name at each tile corner: [x][y] for x in 0..width, y in 0..height.
  late final List<List<String>> corners;
  late final List<List<double>> _blockedCorner;

  final propTiles = <int, PropTileInfo>{};
  final propByName = <String, PropTileInfo>{};
  final props = <PlacedTile>[];
  final interactives = <PlacedTile>[];
  final gameplay = <MapObject>[];

  static String? _prop(CustomProperties p, String name) => p[name]?.value.toString();

  void _parseTilesets() {
    for (final ts in tiled.tilesets) {
      if (ts.name != 'props') continue;
      final first = ts.firstGid ?? 1;
      for (final tile in ts.tiles) {
        final p = tile.properties;
        final name = _prop(p, 'name');
        if (name == null || tile.image?.source == null) continue;
        Vector2? pair(String key) {
          final v = _prop(p, key);
          if (v == null) return null;
          final parts = v.split(',').map(double.parse).toList();
          return Vector2(parts[0], parts[1]);
        }

        final info = PropTileInfo(
          gid: first + tile.localId,
          name: name,
          imageSource: tile.image!.source!,
          width: (tile.image!.width ?? 0).toInt(),
          height: (tile.image!.height ?? 0).toInt(),
          anchorY: double.tryParse(_prop(p, 'anchorY') ?? '') ?? 0,
          collision: double.tryParse(_prop(p, 'collision') ?? '') ?? 0,
          footprint: pair('footprint'),
          layer: _prop(p, 'layer') ?? 'sorted',
          wall: _prop(p, 'wall'),
          walkable: pair('walkable'),
          emitter: _prop(p, 'emitter'),
        );
        propTiles[info.gid] = info;
        propByName[name] = info;
      }
    }
  }

  void _buildCorners() {
    final ground = tiled.layers.whereType<TileLayer>().firstWhere((l) => l.name == 'ground');
    final data = ground.tileData!;
    corners = List.generate(width + 1, (_) => List.filled(height + 1, 'grass'));
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final gid = data[y][x].tile;
        if (gid == 0) continue;
        final tile = tiled.tileByGid(gid);
        final spec = tile == null ? null : _prop(tile.properties, 'corners');
        if (spec == null) continue;
        final c = spec.split(',');
        corners[x][y] = c[0];
        corners[x + 1][y] = c[1];
        corners[x + 1][y + 1] = c[2];
        corners[x][y + 1] = c[3];
      }
    }
    _blockedCorner = [
      for (var x = 0; x <= width; x++) [for (var y = 0; y <= height; y++) blockedTerrains.contains(corners[x][y]) ? 1.0 : 0.0],
    ];
  }

  Map<String, String> _objProps(TiledObject o) => {for (final p in o.properties) p.name: p.value.toString()};

  void _parseObjects() {
    for (final layer in tiled.layers.whereType<ObjectGroup>()) {
      for (final o in layer.objects) {
        if (o.gid != null) {
          final info = propTiles[o.gid!];
          if (info == null) continue;
          // Tile objects are anchored at their image bottom (see props.tsx).
          final shift = info.anchorY / tileHeight;
          final ground = Vector2(o.x / tileHeight - shift, o.y / tileHeight - shift);
          final placed = PlacedTile(info, ground, o.type, o.name, _objProps(o));
          (layer.name == 'interactives' ? interactives : props).add(placed);
        } else {
          gameplay.add(
            MapObject(
              type: o.type,
              name: o.name,
              position: Vector2(o.x / tileHeight, o.y / tileHeight),
              size: Vector2(o.width / tileHeight, o.height / tileHeight),
              isPoint: o.point,
              isEllipse: o.ellipse,
              props: _objProps(o),
            ),
          );
        }
      }
    }
  }

  /// 0 = fully walkable terrain, 1 = fully blocked, bilinear in between.
  double blockedness(double wx, double wy) {
    if (wx < 0 || wy < 0 || wx > width || wy > height) return 1;
    final x0 = wx.floor().clamp(0, width - 1), y0 = wy.floor().clamp(0, height - 1);
    final u = wx - x0, v = wy - y0;
    final a = _blockedCorner[x0][y0], b = _blockedCorner[x0 + 1][y0];
    final c = _blockedCorner[x0 + 1][y0 + 1], d = _blockedCorner[x0][y0 + 1];
    return a * (1 - u) * (1 - v) + b * u * (1 - v) + c * u * v + d * (1 - u) * v;
  }

  bool terrainWalkable(double wx, double wy) => blockedness(wx, wy) < 0.5;

  /// Majority terrain name at a world point.
  String terrainAt(double wx, double wy) {
    final x = wx.round().clamp(0, width), y = wy.round().clamp(0, height);
    return corners[x][y];
  }

  Iterable<MapObject> objectsOfType(String type) => gameplay.where((o) => o.type == type);

  MapObject? object(String type, String name) {
    for (final o in gameplay) {
      if (o.type == type && o.name == name) return o;
    }
    return null;
  }
}
