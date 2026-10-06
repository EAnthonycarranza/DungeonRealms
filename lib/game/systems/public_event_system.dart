import 'dart:ui' show Color;
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../content/game_data.dart';
import '../dungeon_realms_game.dart';
import '../entities/enemy.dart';
import '../entities/event_target.dart';
import '../session.dart';
import '../world/region_map.dart';

/// Runs public events such as Wagon Wheel Wipeout (defend a target from
/// waves until the timer ends).
class PublicEventSystem {
  PublicEventSystem(this.game);

  final DungeonRealmsGame game;
  final _cooldowns = <String, double>{};
  final _rng = math.Random();

  EventDef? active;
  MapObject? _zone;
  EventTargetEntity? target;
  double t = 0;
  int _nextWave = 0;
  final _spawned = <EnemyEntity>[];
  double _hudTimer = 0;

  bool get running => active != null;

  double cooldownOf(String id) => _cooldowns[id] ?? 0;

  bool canStart(String id) => active == null && cooldownOf(id) <= 0;

  void start(String id) {
    final def = game.data.events[id];
    if (def == null || !canStart(id)) return;
    final zone = game.map.object('event', def.zone);
    if (zone == null) return;
    active = def;
    _zone = zone;
    t = 0;
    _nextWave = 0;
    _spawned.clear();
    final tdef = def.target;
    if (tdef != null) {
      // Anchor on the matching prop if there is one inside the zone.
      var at = zone.center;
      for (final p in game.map.props) {
        if (p.info.name == tdef.prop && zone.contains(p.ground)) at = p.ground.clone();
      }
      final entity = EventTargetEntity(name: tdef.name, maxHealth: tdef.hp, ground: at, radius: tdef.radius);
      target = entity;
      game.entityLayer.add(entity);
      game.allies.add(entity);
    }
    game.session.showBanner(def.name.toUpperCase(), subtitle: def.description, style: 'event');
    if (def.npc != null && def.startBark != null) game.npcSay(def.npc!, def.startBark!);
  }

  Vector2 _ringPoint() {
    final c = target?.ground ?? _zone!.center;
    final r = active!.spawnRadius;
    for (var i = 0; i < 30; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final p = c + Vector2(math.cos(a), math.sin(a)) * (r * (0.75 + _rng.nextDouble() * 0.3));
      if (!game.collision.collides(p.x, p.y, 0.4) && p.distanceTo(game.hero.ground) > 3) return p;
    }
    return c + Vector2(r * 0.7, 0);
  }

  void update(double dt) {
    for (final k in _cooldowns.keys.toList()) {
      _cooldowns[k] = math.max(0, _cooldowns[k]! - dt);
    }
    final def = active;
    if (def == null) return;
    t += dt;
    while (_nextWave < def.waves.length && t >= def.waves[_nextWave].at) {
      final wave = def.waves[_nextWave++];
      _spawned.addAll(game.spawns.summonPack(wave.pack, around: _ringPoint(), level: def.level, eventTarget: target, radius: 1.6));
      if (_nextWave > 1) game.session.toast('Wave $_nextWave incoming!');
    }
    final allSpawned = _nextWave >= def.waves.length;
    final remaining = _spawned.where((e) => e.alive).length;
    if (target != null && !target!.alive) {
      _finish(success: false);
      return;
    }
    if (allSpawned && remaining == 0) {
      _finish(success: true);
      return;
    }
    if (t >= def.duration) {
      _finish(success: false);
      return;
    }
    _hudTimer -= dt;
    if (_hudTimer <= 0) {
      _hudTimer = 0.2;
      game.session.event.value = EventHud(
        name: def.name,
        description: '$remaining attackers left',
        timeLeft: math.max(0, def.duration - t),
        targetName: target?.name,
        targetHp: target?.hpFraction ?? 1,
        wave: _nextWave,
        waves: def.waves.length,
      );
    }
  }

  void _finish({required bool success}) {
    final def = active!;
    active = null;
    game.session.event.value = null;
    _cooldowns[def.id] = success ? def.cooldown : 30;
    final at = target?.ground.clone() ?? _zone!.center;
    if (target != null) {
      game.allies.remove(target);
      target!.despawn();
      target = null;
    }
    if (success) {
      game.session.showBanner('EVENT COMPLETE', subtitle: def.name, style: 'quest');
      if (def.npc != null && def.successBark != null) game.npcSay(def.npc!, def.successBark!);
      game.hero.gainXp(def.xp.toDouble());
      if (def.loot != null) game.dropLoot(def.loot!, at: at, level: def.level + 1);
      game.reportEvent(def.id);
    } else {
      game.session.showBanner('EVENT FAILED', subtitle: 'They got away with it. This time.', style: 'danger');
      if (def.npc != null && def.failBark != null) game.npcSay(def.npc!, def.failBark!);
      for (final e in _spawned) {
        if (e.alive) {
          final s = e.position;
          game.particles.emit(x: s.x, y: s.y - 20, color: const Color(0xffcfc2a0), count: 8, speed: 100, life: 0.4, size: 5);
          e.despawn();
        }
      }
    }
    _spawned.clear();
  }

  void onHeroDied() {
    if (active != null) _finish(success: false);
  }
}
