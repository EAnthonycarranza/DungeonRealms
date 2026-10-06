import 'package:flame/components.dart';

import '../dungeon_realms_game.dart';
import '../entities/actor.dart';
import '../entities/enemy.dart';
import '../entities/hero.dart';
import '../entities/interactables.dart';
import '../session.dart';
import '../world/region_map.dart';

class BossArena {
  BossArena(this.zone, this.bossId, this.level, this.spawnPoint);

  final MapObject zone;
  final String bossId;
  final int level;
  final Vector2 spawnPoint;
  final gates = <BossGateEntity>[];
  EnemyEntity? boss;
  bool fighting = false;
  double respawnTimer = 0;
}

/// Boss arenas: engage on entry, seal the gate, track phases for the HUD,
/// reset on wipe, celebrate on victory.
class BossSystem {
  BossSystem(this.game);

  final DungeonRealmsGame game;
  final arenas = <BossArena>[];
  double _hud = 0;

  void load(RegionMap map, Iterable<BossGateEntity> gates) {
    for (final zone in map.objectsOfType('boss_arena')) {
      final bossId = zone.prop('boss') ?? zone.name;
      final spawn = map.gameplay.where((o) => o.type == 'boss_spawn' && o.prop('boss') == bossId).firstOrNull?.center ?? zone.center;
      final arena = BossArena(zone, bossId, int.tryParse(zone.prop('level') ?? '') ?? 8, spawn);
      arena.gates.addAll(gates.where((g) => g.bossId == bossId));
      game.collision.setTagEnabled('gate:$bossId', false);
      arenas.add(arena);
      _spawnBoss(arena);
    }
  }

  void _spawnBoss(BossArena a) {
    a.boss = game.spawns.spawnEnemy(a.bossId, a.spawnPoint, level: a.level);
    a.boss?.faceDirection(Vector2(1, 1));
  }

  void _setGates(BossArena a, bool closed) {
    for (final g in a.gates) {
      g.closed = closed;
    }
    game.collision.setTagEnabled('gate:${a.bossId}', closed);
  }

  void update(double dt) {
    final hero = game.hero;
    for (final a in arenas) {
      final boss = a.boss;
      if (boss == null || boss.despawned) {
        a.respawnTimer -= dt;
        if (a.respawnTimer <= 0 && hero.ground.distanceTo(a.zone.center) > 18) _spawnBoss(a);
        continue;
      }
      if (!a.fighting && boss.alive && hero.alive) {
        final inner = a.zone.center.distanceTo(hero.ground) < a.zone.size.x * 0.36;
        if (inner) _engage(a);
      }
    }
    _hud -= dt;
    if (_hud <= 0) {
      _hud = 0.1;
      _syncHud();
    }
  }

  /// The hero hit a boss whose fight hasn't started: start it if the hero
  /// is inside the arena.
  void provoke(EnemyEntity boss, Actor source) {
    if (source is! HeroEntity) return;
    for (final a in arenas) {
      if (a.boss == boss && !a.fighting && boss.alive && a.zone.contains(source.ground)) _engage(a);
    }
  }

  void _engage(BossArena a) {
    final boss = a.boss!;
    a.fighting = true;
    boss.engaged = true;
    boss.target = game.hero;
    boss.brain.state = 'chase';
    _setGates(a, true);
    game.session.showBanner(boss.def.name.toUpperCase(), subtitle: boss.def.title, style: 'boss');
    if (boss.def.barks.isNotEmpty) boss.say(boss.def.barks.first, duration: 3);
    game.shake(4);
  }

  void _syncHud() {
    final s = game.session;
    // Active boss fight first.
    for (final a in arenas) {
      final boss = a.boss;
      if (a.fighting && boss != null && boss.alive) {
        s.boss.value = BossHud(
          name: boss.def.name,
          title: boss.def.title,
          hpFraction: boss.hpFraction,
          phase: boss.phaseIndex,
          elite: false,
          vulnerable: boss.vulnerableTime > 0,
        );
        return;
      }
    }
    // Otherwise an elite fighting the hero nearby.
    for (final e in game.enemies) {
      if (e.alive && e.def.isElite && e.target == game.hero && e.ground.distanceTo(game.hero.ground) < 14) {
        s.boss.value = BossHud(name: e.def.name, title: e.def.title, hpFraction: e.hpFraction, phase: e.phaseIndex, elite: true);
        return;
      }
    }
    if (s.boss.value != null) s.boss.value = null;
  }

  void onEnemyKilled(EnemyEntity e) {
    for (final a in arenas) {
      if (a.boss != e) continue;
      a.fighting = false;
      a.respawnTimer = 300;
      _setGates(a, false);
      game.onBossDefeated(e);
    }
  }

  /// Hero died: bosses heal up and wait for the next attempt.
  void onHeroDied() {
    for (final a in arenas) {
      final boss = a.boss;
      if (!a.fighting || boss == null) continue;
      a.fighting = false;
      _setGates(a, false);
      if (!boss.alive) continue;
      boss
        ..engaged = false
        ..target = null
        ..hp = boss.maxHp
        ..phaseIndex = 0
        ..vulnerability = 1
        ..vulnerableTime = 0
        ..tint = null
        ..actionSpeed = 1
        ..cooldownRate = 1
        ..moveSpeed = boss.def.stats.speed
        ..interruptCast();
      boss.statuses.clear();
      boss.ground.setFrom(a.spawnPoint);
      boss.brain.state = 'idle';
      // Clear summoned adds inside the arena.
      for (final e in game.enemies) {
        if (e != boss && e.alive && e.zone == null && e.eventTarget == null && a.zone.contains(e.ground)) e.despawn();
      }
    }
  }
}
