import 'package:dungeon_realms/content/game_data.dart';
import 'package:dungeon_realms/game/dungeon_realms_game.dart';
import 'package:dungeon_realms/game/entities/interactables.dart';
import 'package:dungeon_realms/game/input.dart';
import 'package:dungeon_realms/rules/hero_profile.dart';
import 'package:dungeon_realms/rules/items.dart';
import 'package:dungeon_realms/rules/quest_log.dart';
import 'package:dungeon_realms/services/save_repository.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real game (real map, art and content) without a screen and
/// drives it frame by frame. This is the end-to-end safety net for the
/// Goblinwood vertical slice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameData data;
  late MemorySaveRepository saves;

  setUpAll(() async => data = await GameData.load());
  setUp(() => saves = MemorySaveRepository());

  DungeonRealmsGame create() => DungeonRealmsGame(data: data, profile: HeroProfile.create(data, 'ranger', 'leafwarden', ItemFactory(data)), saves: saves);

  void run(DungeonRealmsGame game, double seconds, {double dt = 1 / 30}) {
    for (var t = 0.0; t < seconds; t += dt) {
      game.update(dt);
    }
  }

  testWithGame<DungeonRealmsGame>('Goblinwood loads with everything in place', create, (game) async {
    await game.ready();
    expect(game.map.width, 76);
    expect(game.npcs.length, 4);
    expect(game.waypoints.length, 4);
    expect(game.enemies.length, greaterThan(20));
    expect(game.enemies.where((e) => e.def.id == 'grizzlefang'), hasLength(1));
    expect(game.hero.ground.distanceTo(game.map.objectsOfType('player_start').first.center), lessThan(1));
    // The hero must not start inside anything solid.
    expect(game.collision.collides(game.hero.ground.x, game.hero.ground.y, 0.25), isFalse);
    run(game, 1);
    expect(game.session.loading.value, isFalse);
  });

  testWithGame<DungeonRealmsGame>('every map object points at real content', create, (game) async {
    await game.ready();
    final map = game.map;
    final problems = <String>[];
    void need(bool ok, String message) {
      if (!ok) problems.add(message);
    }

    final region = data.region(game.profile.region);
    need(map.objectsOfType('player_start').isNotEmpty, 'no player_start');
    for (final o in map.objectsOfType('spawn')) {
      need(data.packs.containsKey(o.prop('pack')), 'spawn ${o.name}: unknown pack ${o.prop('pack')}');
      need(int.tryParse(o.prop('level') ?? '') != null, 'spawn ${o.name}: needs a level');
    }
    for (final o in map.objectsOfType('npc')) {
      need(data.npcs.containsKey(o.prop('npc')), 'npc object ${o.name}: unknown npc ${o.prop('npc')}');
    }
    for (final type in ['boss_arena', 'boss_spawn']) {
      for (final o in map.objectsOfType(type)) {
        need(data.enemies[o.prop('boss')]?.isBoss ?? false, '$type ${o.name}: unknown boss ${o.prop('boss')}');
      }
    }
    for (final p in map.interactives) {
      switch (p.type) {
        case 'resource':
          need(data.resources.containsKey(p.props['node']), 'resource ${p.name}: unknown node ${p.props['node']}');
        case 'chest':
          need(data.lootTables.containsKey(p.props['loot']), 'chest ${p.name}: unknown loot ${p.props['loot']}');
        case 'waypoint':
          need(region.waypoints.any((w) => w.id == p.props['waypoint']), 'waypoint ${p.name}: not in region ${region.id}');
        case 'boss_gate':
          need(data.enemies.containsKey(p.props['boss']), 'boss gate ${p.name}: unknown boss ${p.props['boss']}');
      }
    }
    final stones = map.interactives.where((p) => p.type == 'waypoint').map((p) => p.props['waypoint']).toSet();
    for (final w in region.waypoints) {
      need(stones.contains(w.id), 'region waypoint ${w.id} has no stone on the map');
    }
    for (final e in data.events.values) {
      need(map.object('event', e.zone) != null, 'event ${e.id}: no event zone ${e.zone} on the map');
    }
    final triggers = map.objectsOfType('trigger').map((o) => o.prop('discover')).toSet();
    final chests = map.interactives.where((p) => p.type == 'chest').map((p) => p.name).toSet();
    for (final q in data.quests) {
      for (final o in q.objectives) {
        if (o.type == 'discover') need(triggers.contains(o.target), 'quest ${q.id}: no trigger discovers ${o.target}');
        if (o.type == 'open') need(chests.contains(o.target), 'quest ${q.id}: no chest named ${o.target}');
      }
    }
    expect(problems, isEmpty);
  });

  testWithGame<DungeonRealmsGame>('the hero walks with input and collides with the world', create, (game) async {
    await game.ready();
    final start = game.hero.ground.clone();
    game.input.move.setValues(1, 0); // screen right
    run(game, 1.5);
    game.input.move.setZero();
    expect(game.hero.ground.distanceTo(start), greaterThan(2));
    // Walking into the map edge forest should stop us.
    game.input.move.setValues(0, 1);
    run(game, 25);
    expect(game.hero.ground.x, lessThan(game.map.width - 1.0));
    expect(game.hero.ground.y, lessThan(game.map.height - 1.0));
    expect(game.collision.collides(game.hero.ground.x, game.hero.ground.y, 0.2), isFalse);
  });

  testWithGame<DungeonRealmsGame>('quick shots kill a goblin, grant xp and drop loot', create, (game) async {
    await game.ready();
    final goblin = game.enemies.firstWhere((e) => e.def.id == 'goblin_grunt');
    // Stand a few tiles away from the goblin and shoot it.
    game.hero.ground.setFrom(goblin.ground + Vector2(2.5, 2.5));
    game.collision.resolve(game.hero.ground, 0.3);
    game.input.attackHeld = true;
    var t = 0.0;
    while (goblin.alive && t < 20) {
      game.input.mouseWorld = goblin.ground.clone();
      game.update(1 / 30);
      t += 1 / 30;
    }
    game.input.attackHeld = false;
    expect(goblin.alive, isFalse, reason: 'goblin should die within 20s');
    expect(game.profile.kills, greaterThanOrEqualTo(1));
    expect(game.profile.xp + (game.profile.level - 1) * 1000, greaterThan(0));
  });

  testWithGame<DungeonRealmsGame>('every hero ability can be cast', create, (game) async {
    await game.ready();
    game.profile.level = 8;
    game.hero.recomputeStats(fullHeal: true);
    game.hero.ultimate = game.hero.ultimateMax;
    for (final slot in [AbilitySlotId.skill1, AbilitySlotId.skill2, AbilitySlotId.skill3, AbilitySlotId.ultimate, AbilitySlotId.dodge]) {
      game.input.requestAbility(AbilityRequest(slot, aimWorld: game.hero.ground + Vector2(3, 3)));
      run(game, 1.2);
      final a = game.hero.abilityFor(slot)!;
      expect(game.hero.cooldownOf(a.id) > 0 || a.isUltimate, isTrue, reason: '${a.id} should have been cast');
    }
    expect(game.hero.ultimate, lessThan(game.hero.ultimateMax));
  });

  testWithGame<DungeonRealmsGame>('a skill pressed mid-attack is buffered and cuts the attack short', create, (game) async {
    await game.ready();
    game.input.attackHeld = true;
    game.input.mouseWorld = game.hero.ground + Vector2(3, 3);
    run(game, 0.05);
    expect(game.hero.cast, isNotNull, reason: 'the held basic attack should be winding up');
    game.input.requestAbility(AbilityRequest(AbilitySlotId.skill1, aimWorld: game.hero.ground + Vector2(3, 3)));
    run(game, 0.1);
    game.input.attackHeld = false;
    final skill = game.hero.abilityFor(AbilitySlotId.skill1)!;
    expect(game.hero.cooldownOf(skill.id), greaterThan(0));
  });

  testWithGame<DungeonRealmsGame>('monsters ignore a hero resting at a waypoint', create, (game) async {
    await game.ready();
    final stone = game.waypoints.firstWhere((w) => w.waypointId == 'snagtooth_camp');
    game.hero.ground.setFrom(stone.ground + Vector2(0.9, 0.9));
    game.collision.resolve(game.hero.ground, 0.3);
    final hp = game.hero.hp;
    run(game, 4);
    expect(game.enemies.where((e) => e.target == game.hero), isEmpty);
    expect(game.hero.hp, hp);
  });

  testWithGame<DungeonRealmsGame>('talking to Bramble offers and accepts the first quest', create, (game) async {
    await game.ready();
    final bramble = game.npcs.firstWhere((n) => n.def.id == 'captain_bramble');
    game.talkTo(bramble);
    expect(game.session.dialog.value, isNotNull);
    expect(game.session.dialog.value!.options.first.id, 'accept');
    game.chooseDialogOption('accept');
    expect(game.quests.status('goblins_in_my_woods'), QuestStatus.active);
    expect(game.session.dialog.value, isNull);
    expect(game.paused, isFalse);
  });

  testWithGame<DungeonRealmsGame>('mining a copper vein yields ore and day job xp', create, (game) async {
    await game.ready();
    final vein = game.interactables.whereType<ResourceNodeEntity>().firstWhere((n) => n.def.id == 'copper_vein');
    // Goblins interrupt gathering (by design), so clear the area first.
    for (final e in game.enemies.where((e) => e.ground.distanceTo(vein.ground) < 15).toList()) {
      e.despawn();
    }
    game.hero.ground.setFrom(vein.ground + Vector2(0.8, 0.8));
    game.collision.resolve(game.hero.ground, 0.3);
    run(game, 0.3);
    expect(game.hero.nearestInteractable, isNotNull);
    vein.interact();
    run(game, 3);
    expect(game.profile.inventory.materialCount('copper_ore'), greaterThan(0));
    expect(vein.available, isFalse);
    expect(game.profile.dayJob('mining').xp + game.profile.dayJob('mining').level, greaterThan(1));
  });

  testWithGame<DungeonRealmsGame>('entering the hollow engages Grizzlefang and seals the gate', create, (game) async {
    await game.ready();
    final arena = game.bosses.arenas.single;
    game.hero.ground.setFrom(arena.zone.center + Vector2(2, 3));
    game.collision.resolve(game.hero.ground, 0.3);
    run(game, 0.5);
    expect(arena.fighting, isTrue);
    expect(game.session.boss.value?.name, 'Grizzlefang');
    expect(game.collision.isTagEnabled('gate:grizzlefang'), isTrue);
    // Finish him off.
    final boss = arena.boss!;
    boss.hp = 1;
    game.combat.hit(game.hero, boss, 5);
    run(game, 0.5);
    expect(boss.alive, isFalse);
    expect(game.profile.bossKills, contains('normal:grizzlefang'));
    expect(game.collision.isTagEnabled('gate:grizzlefang'), isFalse);
  });

  testWithGame<DungeonRealmsGame>('an idle boss ignores hits from outside its arena and wakes up to hits from inside', create, (game) async {
    await game.ready();
    final arena = game.bosses.arenas.single;
    final boss = arena.boss!;
    game.hero.ground.setFrom(arena.zone.center + Vector2(0, 12));
    expect(game.combat.hit(game.hero, boss, 1), 0);
    expect(boss.hp, boss.maxHp);
    expect(arena.fighting, isFalse);
    // Just inside the arena, short of the spot that triggers the fight.
    game.hero.ground.setFrom(arena.zone.center + Vector2(0, 6));
    expect(game.combat.hit(game.hero, boss, 1), greaterThan(0));
    expect(arena.fighting, isTrue);
  });

  testWithGame<DungeonRealmsGame>("the bramble gate seals Grizzlefang's hollow", create, (game) async {
    await game.ready();
    final inside = game.bosses.arenas.single.zone.center + Vector2(0, 4);
    final outside = game.waypoints.firstWhere((w) => w.waypointId == 'grizzlefang_hollow').ground + Vector2(0.9, 0.9);

    // Flood fill the walkable space a hero-sized circle can reach.
    bool reachable() {
      const step = 0.25, radius = 0.3;
      final cols = (game.map.width / step).floor(), rows = (game.map.height / step).floor();
      final seen = List.filled(cols * rows, false);
      final queue = <(int, int)>[((inside.x / step).floor(), (inside.y / step).floor())];
      final goal = ((outside.x / step).floor(), (outside.y / step).floor());
      while (queue.isNotEmpty) {
        final (cx, cy) = queue.removeLast();
        if (cx < 0 || cy < 0 || cx >= cols || cy >= rows || seen[cy * cols + cx]) continue;
        seen[cy * cols + cx] = true;
        if (game.collision.collides((cx + 0.5) * step, (cy + 0.5) * step, radius)) continue;
        if ((cx - goal.$1).abs() <= 1 && (cy - goal.$2).abs() <= 1) return true;
        queue.addAll([(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]);
      }
      return false;
    }

    expect(reachable(), isTrue, reason: 'the hollow must be open while the gate is down');
    game.collision.setTagEnabled('gate:grizzlefang', true);
    expect(reachable(), isFalse, reason: 'nothing may leave the hollow while the gate is up');
  });

  testWithGame<DungeonRealmsGame>('the wagon event spawns waves and can be saved', create, (game) async {
    await game.ready();
    game.events.start('wagon_wheel_wipeout');
    expect(game.events.running, isTrue);
    run(game, 3);
    expect(game.session.event.value, isNotNull);
    final before = game.enemies.length;
    run(game, 15);
    expect(game.enemies.length, greaterThanOrEqualTo(before));
    await game.saveNow();
    expect(await saves.loadHero(game.profile.id), isNotNull);
  });
}
