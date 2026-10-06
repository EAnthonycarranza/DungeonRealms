import 'dart:ui' show Color;
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';
import '../entities/actor.dart';
import '../entities/enemy.dart';
import '../world/region_map.dart';

/// A Tiled `spawn` zone: keeps one pack alive, respawning it after the pack
/// is wiped and the hero has wandered off.
class SpawnZone {
  SpawnZone(this.object)
    : packId = object.prop('pack') ?? (throw FormatException('spawn zone "${object.name}" needs a "pack" property')),
      level = int.tryParse(object.prop('level') ?? '') ?? 1,
      respawn = double.tryParse(object.prop('respawn') ?? '') ?? 60;

  final MapObject object;
  final String packId;
  final int level;
  final double respawn;
  final members = <EnemyEntity>[];
  double timer = 0;
  bool spawned = false;

  bool get wiped => spawned && members.every((m) => m.dead);
}

class SpawnSystem {
  SpawnSystem(this.game);

  final DungeonRealmsGame game;
  final zones = <SpawnZone>[];
  final _rng = math.Random();

  void load(RegionMap map) {
    for (final o in map.objectsOfType('spawn')) {
      zones.add(SpawnZone(o));
    }
    for (final z in zones) {
      _spawnZone(z);
    }
  }

  void _spawnZone(SpawnZone z) {
    z.members.clear();
    final pack = game.data.packs[z.packId];
    if (pack == null) return;
    final ids = pack.enemyIds.toList();
    final elite = game.difficulty.mechanics.contains('elite_packs') && ids.length > 1 ? _rng.nextInt(ids.length) : -1;
    for (var i = 0; i < ids.length; i++) {
      final p = _walkablePointIn(z.object);
      final e = spawnEnemy(ids[i], p, level: z.level, zone: z, elitePack: i == elite);
      if (e != null) z.members.add(e);
    }
    z.spawned = true;
    z.timer = z.respawn;
  }

  Vector2 _walkablePointIn(MapObject area) {
    for (var i = 0; i < 25; i++) {
      final p = area.randomPoint(_rng);
      if (!game.collision.collides(p.x, p.y, 0.35)) return p;
    }
    return area.center;
  }

  /// Spawns one enemy. Returns null for unknown ids.
  EnemyEntity? spawnEnemy(String id, Vector2 at, {required int level, SpawnZone? zone, Actor? eventTarget, bool elitePack = false}) {
    final def = game.data.enemies[id];
    if (def == null) return null;
    final enemy = EnemyEntity(def: def, level: level, sheet: game.sheet(def.sprite), ground: at.clone(), zone: zone, eventTarget: eventTarget)
      ..elitePack = elitePack;
    game.entityLayer.add(enemy);
    game.enemies.add(enemy);
    return enemy;
  }

  /// Summons a pack around [around] (boss adds, rallies, event waves).
  List<EnemyEntity> summonPack(String packId, {required Vector2 around, required int level, Actor? leader, Actor? eventTarget, double radius = 2.5}) {
    final pack = game.data.packs[packId];
    if (pack == null) return const [];
    final spawned = <EnemyEntity>[];
    for (final id in pack.enemyIds) {
      Vector2 p = around;
      for (var i = 0; i < 20; i++) {
        final a = _rng.nextDouble() * math.pi * 2;
        final r = radius * (0.6 + _rng.nextDouble() * 0.6);
        final c = around + Vector2(math.cos(a), math.sin(a)) * r;
        if (!game.collision.collides(c.x, c.y, 0.35)) {
          p = c;
          break;
        }
      }
      final e = spawnEnemy(id, p, level: level, eventTarget: eventTarget);
      if (e == null) continue;
      if (leader is EnemyEntity && leader.target != null) {
        e.target = leader.target;
        e.brain.state = 'chase';
      }
      if (eventTarget != null) e.brain.state = 'chase';
      final s = game.iso.toScreenV(p);
      game.particles.emit(x: s.x, y: s.y, color: const Color(0xffcfc2a0), count: 10, speed: 120, life: 0.5, size: 5, gravity: -40);
      spawned.add(e);
    }
    return spawned;
  }

  void update(double dt) {
    final hero = game.hero;
    for (final z in zones) {
      if (!z.wiped) continue;
      z.timer -= dt;
      if (z.timer > 0) continue;
      // Only respawn out of sight.
      if (hero.ground.distanceTo(z.object.center) < 15) {
        z.timer = 3;
        continue;
      }
      _spawnZone(z);
    }
  }

  /// Hero died or travelled: reset aggro so packs go home and heal.
  void resetAggro() {
    for (final e in game.enemies) {
      if (!e.alive || e.eventTarget != null) continue;
      e.target = null;
      e.brain.state = 'return';
    }
  }
}
