import 'dart:convert';

import 'package:flutter/services.dart';

import 'ability_defs.dart';
import 'enemy_defs.dart';
import 'hero_defs.dart';
import 'item_defs.dart';
import 'json_reader.dart';
import 'loot_defs.dart';
import 'quest_defs.dart';
import 'sprite_meta.dart';
import 'world_defs.dart';

export 'ability_defs.dart';
export 'enemy_defs.dart';
export 'hero_defs.dart';
export 'item_defs.dart';
export 'loot_defs.dart';
export 'quest_defs.dart';
export 'sprite_meta.dart';
export 'world_defs.dart';

/// All static game content, parsed from `game_data/*.json`.
///
/// This is the single source of truth for content. Systems receive
/// definitions from here and never hard-code numbers that belong in data.
class GameData {
  GameData._(Map<String, JsonMap> files, this.sprites) {
    JsonReader file(String name) => JsonReader(files[name]!, name);

    for (final h in file('heroes.json').objects('heroes')) {
      final hero = HeroDef.fromJson(h);
      heroes[hero.id] = hero;
    }
    for (final a in file('abilities.json').objects('abilities')) {
      final ability = AbilityDef.fromJson(a);
      abilities[ability.id] = ability;
    }
    final enemiesFile = file('enemies.json');
    enemyScaling = EnemyScaling.fromJson(enemiesFile.obj('scaling'));
    for (final e in enemiesFile.objects('enemies')) {
      final enemy = EnemyDef.fromJson(e);
      enemies[enemy.id] = enemy;
    }
    for (final p in enemiesFile.objects('packs')) {
      final pack = PackDef.fromJson(p);
      packs[pack.id] = pack;
    }

    final itemsFile = file('items.json');
    rarities = [for (final r in itemsFile.objects('rarities')) RarityDef.fromJson(r)];
    slots = [for (final s in itemsFile.objects('slots')) SlotDef.fromJson(s)];
    for (final s in itemsFile.objects('stats')) {
      final stat = StatDef.fromJson(s);
      stats[stat.id] = stat;
    }
    affixes = [for (final a in itemsFile.objects('affixes')) AffixDef.fromJson(a)];
    for (final b in itemsFile.objects('bases')) {
      final base = ItemBaseDef.fromJson(b);
      bases[base.id] = base;
    }
    for (final l in itemsFile.objects('legendaries')) {
      final legendary = LegendaryDef.fromJson(l);
      legendaries[legendary.id] = legendary;
    }
    for (final m in itemsFile.objects('materials')) {
      final material = MaterialDef.fromJson(m);
      materials[material.id] = material;
    }
    epicNames = EpicNameParts.fromJson(itemsFile.obj('epicNames'));

    for (final t in file('loot_tables.json').objects('tables')) {
      final table = LootTableDef.fromJson(t);
      lootTables[table.id] = table;
    }
    quests = [for (final q in file('quests.json').objects('quests')) QuestDef.fromJson(q)];
    for (final n in file('npcs.json').objects('npcs')) {
      final npc = NpcDef.fromJson(n);
      npcs[npc.id] = npc;
    }

    final world = file('world.json');
    final terrainJson = world.obj('terrain');
    for (final id in terrainJson.json.keys) {
      terrain[id] = TerrainRule.fromJson(id, terrainJson.obj(id));
    }
    regions = [for (final r in world.objects('regions')) RegionDef.fromJson(r)];
    for (final r in world.objects('resources')) {
      final res = ResourceDef.fromJson(r);
      resources[res.id] = res;
    }
    for (final d in world.objects('dayJobs')) {
      final job = DayJobDef.fromJson(d);
      dayJobs[job.id] = job;
    }
    for (final e in world.objects('events')) {
      final event = EventDef.fromJson(e);
      events[event.id] = event;
    }
    potion = PotionDef.fromJson(world.obj('potion'));
    healthOrb = HealthOrbDef.fromJson(world.obj('healthOrb'));
    progression = ProgressionDef.fromJson(file('progression.json'));
  }

  /// Every JSON file under game_data/ that [load] reads.
  static const files = [
    'heroes.json',
    'abilities.json',
    'enemies.json',
    'items.json',
    'loot_tables.json',
    'quests.json',
    'npcs.json',
    'world.json',
    'progression.json',
  ];

  final heroes = <String, HeroDef>{};
  final abilities = <String, AbilityDef>{};
  late final EnemyScaling enemyScaling;
  final enemies = <String, EnemyDef>{};
  final packs = <String, PackDef>{};
  late final List<RarityDef> rarities;
  late final List<SlotDef> slots;
  final stats = <String, StatDef>{};
  late final List<AffixDef> affixes;
  final bases = <String, ItemBaseDef>{};
  final legendaries = <String, LegendaryDef>{};
  final materials = <String, MaterialDef>{};
  late final EpicNameParts epicNames;
  final lootTables = <String, LootTableDef>{};
  late final List<QuestDef> quests;
  final npcs = <String, NpcDef>{};
  final terrain = <String, TerrainRule>{};
  late final List<RegionDef> regions;
  final resources = <String, ResourceDef>{};
  final dayJobs = <String, DayJobDef>{};
  final events = <String, EventDef>{};
  late final PotionDef potion;
  late final HealthOrbDef healthOrb;
  late final ProgressionDef progression;
  final Map<String, SpriteSheetMeta> sprites;

  RarityDef rarity(String id) => rarities.firstWhere((r) => r.id == id);
  QuestDef quest(String id) => quests.firstWhere((q) => q.id == id);
  RegionDef region(String id) => regions.firstWhere((r) => r.id == id);
  DifficultyDef difficulty(String id) => progression.difficulties.firstWhere((d) => d.id == id, orElse: () => progression.difficulties.first);

  /// Sprite sheet ids referenced by heroes, enemies and NPCs.
  static Set<String> spriteIdsIn(Map<String, JsonMap> files) {
    final ids = <String>{};
    for (final h in JsonReader(files['heroes.json']!, 'heroes').objects('heroes')) {
      for (final l in h.objects('looks')) {
        final s = l.strOr('sprite');
        if (s != null) ids.add(s);
      }
    }
    for (final e in JsonReader(files['enemies.json']!, 'enemies').objects('enemies')) {
      ids.add(e.str('sprite'));
    }
    for (final n in JsonReader(files['npcs.json']!, 'npcs').objects('npcs')) {
      ids.add(n.str('sprite'));
    }
    return ids;
  }

  /// Builds game data from already-decoded JSON (used by tests and tools).
  factory GameData.fromJson(Map<String, JsonMap> files, Map<String, JsonMap> spriteFiles) {
    final sprites = {for (final e in spriteFiles.entries) e.key: SpriteSheetMeta.fromJson(e.key, JsonReader(e.value, '${e.key}.json'))};
    return GameData._(files, sprites);
  }

  /// Loads every content file from the asset bundle.
  static Future<GameData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final files = <String, JsonMap>{};
    for (final f in GameData.files) {
      files[f] = (jsonDecode(await b.loadString('game_data/$f')) as Map).cast<String, Object?>();
    }
    final spriteFiles = <String, JsonMap>{};
    for (final id in spriteIdsIn(files)) {
      spriteFiles[id] = (jsonDecode(await b.loadString('assets/images/sprites/$id.json')) as Map).cast<String, Object?>();
    }
    return GameData.fromJson(files, spriteFiles);
  }

  /// Cross-reference checks. Returns human readable problems (empty = OK).
  List<String> validate() {
    final problems = <String>[];
    void need(bool ok, String message) {
      if (!ok) problems.add(message);
    }

    final rarityIds = rarities.map((r) => r.id).toSet();
    final slotIds = slots.map((s) => s.id).toSet();
    final enemyTags = enemies.values.expand((e) => e.tags).toSet();
    final itemIds = {...materials.keys};

    for (final h in heroes.values) {
      if (!h.playable) {
        need(h.looks.isNotEmpty, 'hero ${h.id}: needs at least one look');
        continue;
      }
      for (final id in [h.basicAbility, h.dodgeAbility, ...h.abilities.map((a) => a.abilityId)]) {
        need(id != null && abilities.containsKey(id), 'hero ${h.id}: unknown ability $id');
      }
      for (final l in h.looks) {
        need(l.sprite != null && sprites.containsKey(l.sprite), 'hero ${h.id}/${l.id}: missing sprite ${l.sprite}');
        for (final e in const ['idle', 'stunned', 'attack', 'ultimate', 'panic']) {
          need(l.expressions.containsKey(e), 'hero ${h.id}/${l.id}: missing expression $e');
        }
        final sheet = sprites[l.sprite];
        if (sheet != null) {
          for (final id in [h.basicAbility, h.dodgeAbility, ...h.abilities.map((a) => a.abilityId)]) {
            final anim = abilities[id]?.animation;
            if (anim != null) need(sheet.animations.containsKey(anim), 'hero ${h.id}: sprite ${l.sprite} lacks animation $anim');
          }
        }
      }
      for (final g in h.startingGear) {
        need(g.base == null || bases.containsKey(g.base), 'hero ${h.id}: unknown starting base ${g.base}');
        need(rarityIds.contains(g.rarity), 'hero ${h.id}: unknown rarity ${g.rarity}');
      }
    }

    for (final a in abilities.values) {
      if (a.pack != null) need(packs.containsKey(a.pack), 'ability ${a.id}: unknown pack ${a.pack}');
      if (a.behavior == AbilityBehavior.projectile || a.behavior == AbilityBehavior.projectileFan) {
        need(a.projectile != null, 'ability ${a.id}: projectile behavior needs "projectile"');
      }
      for (final e in a.effects) {
        need(const {'root', 'slow', 'stun', 'burn'}.contains(e.status), 'ability ${a.id}: unknown status ${e.status}');
      }
    }

    for (final e in enemies.values) {
      need(sprites.containsKey(e.sprite), 'enemy ${e.id}: missing sprite ${e.sprite}');
      need(const {'melee', 'ranged', 'caster', 'phased'}.contains(e.ai), 'enemy ${e.id}: unknown ai ${e.ai}');
      for (final id in e.allAbilities) {
        need(abilities.containsKey(id), 'enemy ${e.id}: unknown ability $id');
        final anim = abilities[id]?.animation;
        final sheet = sprites[e.sprite];
        if (anim != null && sheet != null) {
          need(sheet.animations.containsKey(anim), 'enemy ${e.id}: sprite ${e.sprite} lacks animation $anim');
        }
      }
      if (e.ai == 'phased') need(e.phases.isNotEmpty, 'enemy ${e.id}: phased ai needs phases');
      if (e.loot != null) need(lootTables.containsKey(e.loot), 'enemy ${e.id}: unknown loot table ${e.loot}');
    }

    for (final p in packs.values) {
      for (final m in p.members) {
        need(enemies.containsKey(m.enemy), 'pack ${p.id}: unknown enemy ${m.enemy}');
      }
    }

    for (final b in bases.values) {
      need(slotIds.contains(b.slot), 'base ${b.id}: unknown slot ${b.slot}');
      need(stats.containsKey(b.implicit.stat), 'base ${b.id}: unknown stat ${b.implicit.stat}');
      for (final c in b.classes) {
        need(heroes.containsKey(c), 'base ${b.id}: unknown hero class $c');
      }
    }
    for (final a in affixes) {
      need(stats.containsKey(a.stat), 'affix ${a.id}: unknown stat ${a.stat}');
      for (final s in a.slots) {
        need(slotIds.contains(s), 'affix ${a.id}: unknown slot $s');
      }
    }
    for (final l in legendaries.values) {
      need(bases.containsKey(l.base), 'legendary ${l.id}: unknown base ${l.base}');
      for (final s in l.fixed.keys) {
        need(stats.containsKey(s), 'legendary ${l.id}: unknown stat $s');
      }
      if (l.power.ability != null) {
        need(abilities.containsKey(l.power.ability), 'legendary ${l.id}: unknown ability ${l.power.ability}');
      }
    }

    for (final t in lootTables.values) {
      for (final id in t.unique?.pool ?? const <String>[]) {
        need(legendaries.containsKey(id), 'loot ${t.id}: unknown legendary $id');
      }
      for (final m in t.materials) {
        need(materials.containsKey(m.item), 'loot ${t.id}: unknown material ${m.item}');
      }
      for (final r in t.items?.rarityWeights.keys ?? const <String>[]) {
        need(rarityIds.contains(r), 'loot ${t.id}: unknown rarity $r');
      }
    }

    final questIds = quests.map((q) => q.id).toSet();
    for (final q in quests) {
      need(npcs.containsKey(q.giver), 'quest ${q.id}: unknown giver ${q.giver}');
      for (final r in q.requires) {
        need(questIds.contains(r), 'quest ${q.id}: unknown required quest $r');
      }
      for (final o in q.objectives) {
        switch (o.type) {
          case 'kill':
            need(
              (o.enemy != null && enemies.containsKey(o.enemy)) || (o.tag != null && enemyTags.contains(o.tag)),
              'quest ${q.id}: kill objective needs a known enemy or tag',
            );
          case 'collect':
            need(itemIds.contains(o.item), 'quest ${q.id}: unknown item ${o.item}');
          case 'event':
            need(events.containsKey(o.event), 'quest ${q.id}: unknown event ${o.event}');
          case 'discover':
          case 'open':
            need(o.target != null, 'quest ${q.id}: ${o.type} objective needs a target');
          case 'talk':
            need(npcs.containsKey(o.npc), 'quest ${q.id}: unknown npc ${o.npc}');
          default:
            problems.add('quest ${q.id}: unknown objective type ${o.type}');
        }
      }
      for (final i in q.rewards.items) {
        need(i.base == null || bases.containsKey(i.base), 'quest ${q.id}: unknown reward base ${i.base}');
        need(rarityIds.contains(i.rarity), 'quest ${q.id}: unknown reward rarity ${i.rarity}');
      }
      if (q.rewards.unique != null) {
        need(legendaries.containsKey(q.rewards.unique), 'quest ${q.id}: unknown unique ${q.rewards.unique}');
      }
    }

    for (final n in npcs.values) {
      need(sprites.containsKey(n.sprite), 'npc ${n.id}: missing sprite ${n.sprite}');
    }
    for (final r in resources.values) {
      need(materials.containsKey(r.item), 'resource ${r.id}: unknown item ${r.item}');
      need(dayJobs.containsKey(r.skill), 'resource ${r.id}: unknown day job ${r.skill}');
    }
    for (final e in events.values) {
      for (final w in e.waves) {
        need(packs.containsKey(w.pack), 'event ${e.id}: unknown pack ${w.pack}');
      }
      if (e.loot != null) need(lootTables.containsKey(e.loot), 'event ${e.id}: unknown loot ${e.loot}');
      if (e.npc != null) need(npcs.containsKey(e.npc), 'event ${e.id}: unknown npc ${e.npc}');
    }
    for (final r in regions) {
      if (r.playable) {
        need(r.map != null, 'region ${r.id}: playable region needs a map');
        need(r.waypoints.any((w) => w.id == r.startWaypoint), 'region ${r.id}: playable region needs a startWaypoint from its waypoints');
      }
    }
    final mechanicIds = progression.mechanics.map((m) => m.id).toSet();
    for (final d in progression.difficulties) {
      for (final m in d.mechanics) {
        need(mechanicIds.contains(m), 'difficulty ${d.id}: unknown mechanic $m');
      }
    }
    return problems;
  }
}
