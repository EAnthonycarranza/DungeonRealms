import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';

import '../content/game_data.dart';
import '../rules/hero_profile.dart';
import '../rules/items.dart';
import '../rules/loot.dart';
import '../rules/quest_log.dart';
import '../services/save_repository.dart';
import 'combat/ability_runner.dart';
import 'combat/area_effect.dart';
import 'combat/combat_system.dart';
import 'entities/actor.dart';
import 'entities/enemy.dart';
import 'entities/entity.dart';
import 'entities/hero.dart';
import 'entities/interactables.dart';
import 'entities/loot_drop.dart';
import 'entities/npc.dart';
import 'fx/ambient.dart';
import 'fx/fx.dart';
import 'input.dart';
import 'render/character_sprite.dart';
import 'session.dart';
import 'systems/boss_system.dart';
import 'systems/public_event_system.dart';
import 'systems/quest_director.dart';
import 'systems/spawn_system.dart';
import 'world/aim_indicator.dart';
import 'world/collision_world.dart';
import 'world/iso.dart';
import 'world/layers.dart';
import 'world/nav_grid.dart';
import 'world/region_map.dart';

class _Delayed {
  _Delayed(this.time, this.fn);
  double time;
  final void Function() fn;
}

/// The Flame game: one region, one hero, all real-time systems.
///
/// Flutter UI talks to it only through [session] (state) and the
/// [GameCommands] methods implemented below (commands).
class DungeonRealmsGame extends FlameGame implements GameCommands {
  DungeonRealmsGame({required this.data, required this.profile, required this.saves, GameSession? session}) : session = session ?? GameSession() {
    this.session.commands = this;
  }

  @override
  final GameData data;
  @override
  final HeroProfile profile;
  final SaveRepository saves;
  final GameSession session;
  @override
  final input = InputState();

  late final Iso iso;
  late final RegionMap map;
  late final CollisionWorld collision;
  late final NavGrid nav;
  FlowField? heroFlow;

  late final GroundLayer groundLayer;
  late final EntityLayer entityLayer;
  late final OverlayLayer overlay;
  late final ParticleSystem particles;

  late final HeroEntity hero;
  final enemies = <EnemyEntity>[];
  final allies = <Actor>[];
  final npcs = <NpcEntity>[];
  final interactables = <Interactable>[];
  final waypoints = <WaypointEntity>[];

  late final CombatSystem combat;
  late final AbilityRunner abilities;
  late final SpawnSystem spawns;
  late final PublicEventSystem events;
  late final BossSystem bosses;
  late final QuestDirector questDirector;
  late final ItemFactory items;
  late final LootRoller loot;
  late final QuestLog quests;

  double time = 0;
  int frameCounter = 0;
  double _shake = 0;
  final _rng = math.Random();
  final _timers = <_Delayed>[];
  final _sheets = <String, CharacterSheet>{};
  final _propImages = <String, Image>{};
  final _icons = <String, Image>{};
  late final Images _tileImages;
  double _hudTimer = 0;
  double _saveTimer = 20;
  bool _saveRequested = false;
  double _flowTimer = 0;
  int _flowCellX = -1, _flowCellY = -1;
  String? _currentArea;
  final _discoveredTriggers = <String>{};
  final _cameraTarget = Vector2.zero();

  DifficultyDef get difficulty => data.difficulty(profile.difficulty);

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  @override
  Color backgroundColor() => const Color(0xff0c1a10);

  @override
  Future<void> onLoad() async {
    session.loading.value = true;
    final region = data.region(profile.region);
    _tileImages = Images(prefix: 'assets/tiles/');
    final tiled = await TiledComponent.load(
      region.map!,
      Vector2(128, 64),
      prefix: 'assets/tiles/',
      images: _tileImages,
      tsxPackingFilter: (ts) => ts.name != 'props',
      priority: -10,
    );
    world.add(tiled);
    map = RegionMap(
      tiled.tileMap.map,
      blockedTerrains: {
        for (final t in data.terrain.values)
          if (!t.walkable) t.id,
      },
    );
    iso = Iso(mapWidth: map.width, mapHeight: map.height);
    collision = CollisionWorld(map);
    nav = NavGrid(collision);

    groundLayer = GroundLayer();
    entityLayer = EntityLayer();
    overlay = OverlayLayer();
    particles = ParticleSystem();
    world
      ..add(groundLayer)
      ..add(entityLayer)
      ..add(overlay);
    overlay.add(particles);
    groundLayer.add(AimIndicator());

    items = ItemFactory(data);
    loot = LootRoller(data, items);
    quests = QuestLog(data, profile.quests);
    profile.quests = quests.states;
    combat = CombatSystem(this);
    abilities = AbilityRunner(this);
    spawns = SpawnSystem(this);
    events = PublicEventSystem(this);
    bosses = BossSystem(this);
    questDirector = QuestDirector(this);

    await _loadSheets();
    await _loadProps();
    await _loadIcons();
    _spawnNpcs();
    _spawnHero();
    spawns.load(map);
    bosses.load(map, entityLayer.children.whereType<BossGateEntity>());
    overlay.add(AmbientLeaves());

    camera.viewfinder.anchor = Anchor.center;
    _cameraTarget.setFrom(hero.position);
    camera.viewfinder.position = hero.position.clone();
    _updateZoom();
    _refreshMarkers();
    _syncHud(force: true);
    session.areaName.value = region.name;
    session.loading.value = false;
    session.showBanner(region.name.toUpperCase(), subtitle: region.levelLabel, style: 'area');
  }

  Future<void> _loadSheets() async {
    final ids = <String>{
      for (final l in data.heroes[profile.heroClass]!.looks)
        if (l.sprite != null) l.sprite!,
      for (final e in data.enemies.values) e.sprite,
      for (final n in data.npcs.values) n.sprite,
    };
    for (final id in ids) {
      final meta = data.sprites[id]!;
      _sheets[id] = CharacterSheet(meta, await images.load('sprites/${meta.image}'));
    }
  }

  CharacterSheet sheet(String id) => _sheets[id]!;

  Future<Image> propImage(PropTileInfo info) async => _propImages[info.imageSource] ??= await _tileImages.load(info.imageSource);

  Future<void> _loadProps() async {
    final resources = {for (final r in data.resources.values) r.id: r};
    for (final p in map.props) {
      final img = await propImage(p.info);
      final sprite = PropSprite(p, img, iso.toScreenV(p.ground));
      if (p.info.isGroundLayer) {
        groundLayer.groundProps.add(sprite);
      } else {
        entityLayer.addProp(sprite);
      }
    }
    for (final p in map.interactives) {
      final img = await propImage(p.info);
      switch (p.type) {
        case 'resource':
          final def = resources[p.props['node']];
          if (def == null) continue;
          final depletedInfo = map.propByName[def.depletedProp]!;
          final node = ResourceNodeEntity(p, img, def: def, depletedImage: await propImage(depletedInfo), depletedInfo: depletedInfo);
          entityLayer.add(node);
          interactables.add(node);
        case 'chest':
          final openInfo = map.propByName['chest_open']!;
          final chest = ChestEntity(
            p,
            img,
            openImage: await propImage(openInfo),
            openInfo: openInfo,
            lootTable: p.props['loot'] ?? 'hollow_chest',
            opened: profile.opened.contains(p.name),
          );
          entityLayer.add(chest);
          interactables.add(chest);
        case 'waypoint':
          final id = p.props['waypoint'] ?? p.name;
          final def = data.region(profile.region).waypoints.where((w) => w.id == id).firstOrNull;
          final activeInfo = map.propByName['waypoint_stone_active']!;
          final wp = WaypointEntity(
            p,
            img,
            activeImage: await propImage(activeInfo),
            waypointId: id,
            waypointName: def?.name ?? id,
            discovered: profile.waypoints.contains(id),
          );
          entityLayer.add(wp);
          interactables.add(wp);
          waypoints.add(wp);
        case 'boss_gate':
          entityLayer.add(BossGateEntity(p, img, bossId: p.props['boss'] ?? ''));
      }
    }
  }

  Future<void> _loadIcons() async {
    final ids = <String>{
      for (final s in data.slots) s.icon,
      for (final b in data.bases.values) b.icon,
      for (final l in data.legendaries.values) l.icon,
      for (final m in data.materials.values) m.icon,
      'currency_gold',
      'currency_shiny_bits',
    };
    for (final id in ids) {
      _icons[id] = await images.load('icons/$id.png');
    }
  }

  Image? icon(String id) => _icons[id];

  void _spawnNpcs() {
    for (final o in map.objectsOfType('npc')) {
      final def = data.npcs[o.prop('npc')];
      if (def == null) continue;
      final npc = NpcEntity(def: def, sheet: sheet(def.sprite), ground: o.center);
      entityLayer.add(npc);
      npcs.add(npc);
      interactables.add(npc);
    }
  }

  /// Waypoint stones are sanctuaries: monsters don't notice a hero standing
  /// next to one (damage still pulls them), so respawning is never a trap.
  static const sanctuaryRadius = 5.0;

  bool inSanctuary(Vector2 p) => waypoints.any((w) => w.ground.distanceTo(p) < sanctuaryRadius);

  Vector2 _waypointSpawn(String id) {
    final wp = waypoints.where((w) => w.waypointId == id).firstOrNull;
    if (wp == null) return map.objectsOfType('player_start').first.center;
    // Stand just in front of the stone.
    final p = wp.ground + Vector2(0.9, 0.9);
    collision.resolve(p, 0.3);
    return p;
  }

  void _spawnHero() {
    final def = data.heroes[profile.heroClass]!;
    final look = def.look(profile.look);
    final start = profile.playSeconds < 1 ? map.objectsOfType('player_start').first.center : _waypointSpawn(profile.lastWaypoint);
    hero = HeroEntity(def: def, profile: profile, sheet: sheet(look.sprite!), ground: start);
    entityLayer.add(hero);
  }

  // ---------------------------------------------------------------------------
  // Frame
  // ---------------------------------------------------------------------------

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _updateZoom();
  }

  void _updateZoom() {
    final s = canvasSize;
    // Show roughly the same amount of world on phones and monitors.
    final byHeight = s.y / 860;
    final byWidth = s.x / 1700;
    camera.viewfinder.zoom = math.max(byHeight, byWidth).clamp(0.42, 1.5);
  }

  Rect cameraView() => camera.visibleWorldRect.inflate(180);

  @override
  void update(double dt) {
    final step = math.min(dt, 1 / 20);
    time += step;
    frameCounter++;
    for (var i = _timers.length - 1; i >= 0; i--) {
      final t = _timers[i];
      t.time -= step;
      if (t.time <= 0) {
        _timers.removeAt(i);
        t.fn();
      }
    }
    super.update(step);
    enemies.removeWhere((e) => e.despawned);
    spawns.update(step);
    events.update(step);
    bosses.update(step);
    _updateFlow(step);
    _updateCamera(step);
    entityLayer.updateOcclusion(step, hero);
    _updateAreas();
    profile.playSeconds += step;
    _hudTimer -= step;
    if (_hudTimer <= 0) {
      _hudTimer = 0.1;
      _syncHud();
    } else {
      session.hp.value = hero.hp;
    }
    _saveTimer -= step;
    if (_saveTimer <= 0 || _saveRequested) {
      _saveTimer = 20;
      _saveRequested = false;
      unawaited(saveNow());
    }
  }

  void _updateFlow(double dt) {
    _flowTimer -= dt;
    if (_flowTimer > 0) return;
    _flowTimer = 0.25;
    final cx = nav.cellX(hero.ground.x), cy = nav.cellY(hero.ground.y);
    if (cx == _flowCellX && cy == _flowCellY && heroFlow != null) return;
    _flowCellX = cx;
    _flowCellY = cy;
    heroFlow = nav.flowTo(hero.ground, radiusCells: 40);
  }

  void _updateCamera(double dt) {
    // Look slightly ahead of the hero's facing direction.
    final ahead = iso.worldDirToScreen(hero.moveIntent.x, hero.moveIntent.y)..scale(0.9);
    _cameraTarget.setFrom(hero.position + ahead - Vector2(0, 40));
    final vf = camera.viewfinder;
    final k = 1 - math.exp(-dt * 6);
    vf.position = vf.position + (_cameraTarget - vf.position) * k;
    if (_shake > 0) {
      _shake = math.max(0, _shake - dt * 18);
      vf.position = vf.position + Vector2((_rng.nextDouble() - 0.5) * _shake * 2, (_rng.nextDouble() - 0.5) * _shake * 2);
    }
  }

  void shake(double amount) => _shake = math.max(_shake, amount);

  void after(double seconds, void Function() fn) => _timers.add(_Delayed(seconds, fn));

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Living actors hostile to [faction].
  Iterable<Actor> opponentsOf(Faction faction) sync* {
    if (faction == Faction.hero) {
      for (final e in enemies) {
        if (e.alive) yield e;
      }
    } else {
      if (hero.alive) yield hero;
      for (final a in allies) {
        if (a.alive) yield a;
      }
    }
  }

  Iterable<Actor> alliesOf(Actor actor) sync* {
    if (actor.faction == Faction.enemy) {
      for (final e in enemies) {
        if (e.alive) yield e;
      }
    } else {
      yield hero;
      yield* allies;
    }
  }

  // ---------------------------------------------------------------------------
  // Feedback helpers
  // ---------------------------------------------------------------------------

  void floatText(Actor target, String text, Color color, {double size = 22, double offsetY = 0}) {
    final p = target.position.clone()
      ..y -= target.visualHeight * target.renderScale + 8 + target.z - offsetY
      ..x += (_rng.nextDouble() - 0.5) * 30;
    overlay.add(FloatingText(text, at: p, color: color, size: size));
  }

  void spawnFallingArrow(Vector2 screen) => overlay.add(FallingArrowFx(screen));

  void npcSay(String npcId, String text) {
    for (final n in npcs) {
      if (n.def.id == npcId) n.say(text, duration: 4);
    }
  }

  // ---------------------------------------------------------------------------
  // Gameplay events
  // ---------------------------------------------------------------------------

  void onEnemyKilled(EnemyEntity enemy, Actor? killer) {
    profile.kills++;
    if (hero.alive) hero.gainXp(enemy.xpValue);
    if (enemy.def.loot != null) dropLoot(enemy.def.loot!, at: enemy.ground, level: enemy.level);
    final changed = quests.onKill(enemy.def);
    if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
    if (enemy.def.deathBark != null) enemy.say(enemy.def.deathBark!, duration: 2.5);
    bosses.onEnemyKilled(enemy);
    if (difficulty.mechanics.contains('hot_sauce') && !enemy.def.isBoss) {
      groundLayer.add(
        AreaEffect(
          owner: enemy,
          ability: null,
          center: enemy.ground.clone(),
          radius: 1.1,
          delay: 0.3,
          duration: 3,
          tickInterval: 0.5,
          damage: 0,
          tickDamage: 0.25,
          effects: const [],
          visual: 'hot_sauce',
        ),
      );
    }
  }

  void onActorKilled(Actor actor) {}

  void onHeroKilled(Actor? killer) {
    profile.deaths++;
    hero.cancelGather();
    events.onHeroDied();
    final name = killer is EnemyEntity ? killer.def.name : 'Mysterious Forces';
    const quips = [
      'Probably the goblins\' fault.',
      'The paperwork for this is enormous.',
      'Have you tried not getting hit?',
      'Granny Gristle is very disappointed.',
      'Even the bear feels a little bad.',
    ];
    session.death.value = DeathState(killer: name, quip: quips[_rng.nextInt(quips.length)]);
    session.mood.value = PortraitMood.panic;
  }

  void onHeroLevelUp(int level) {
    session.showBanner('LEVEL $level!', subtitle: 'Stronger. Pointier. Slightly taller.', style: 'level');
    particles.ring(hero.position.x, hero.position.y - 10, const Color(0xffffc94f), size: 90);
    particles.emit(x: hero.position.x, y: hero.position.y - 40, color: const Color(0xffffe066), count: 30, speed: 180, life: 0.9, size: 4, gravity: -60);
    for (final s in hero.slots) {
      if (s.unlockLevel == level) {
        session.toast('New skill unlocked: ${s.ability.name}!', icon: s.ability.icon, color: 0xff82f16d);
      }
    }
    _syncHud(force: true);
    saveSoon();
  }

  void onBossPhase(EnemyEntity boss, int phase) {
    if (boss.def.isBoss) {
      final subtitle = phase == 1 ? 'He called for snacks. The snacks have clubs.' : 'He found the honey. THIS SEEMS BAD.';
      session.showBanner('PHASE ${phase + 1}', subtitle: subtitle, style: 'danger');
    }
  }

  void onBossDefeated(EnemyEntity boss) {
    profile.bossKills.add('${profile.difficulty}:${boss.def.id}');
    session.showBanner('${boss.def.name.toUpperCase()} DEFEATED', subtitle: 'Goblinwood breathes a sigh of relief', style: 'boss');
    shake(10);
    final unlocked = profile.unlockedDifficulties(data);
    if (unlocked.length > 1 && boss.def.id == 'grizzlefang') {
      session.toast('New world difficulty unlocked: ${unlocked.last.name}! (Ask Captain Bramble)', color: 0xffff8a2b);
    }
    saveSoon();
  }

  void dropLoot(String table, {required Vector2 at, required int level}) {
    final drops = loot.roll(table, level: level, heroClass: profile.heroClass, difficulty: difficulty, goldFind: hero.stats.goldFind);
    for (final d in drops) {
      final a = _rng.nextDouble() * math.pi * 2;
      final speed = 0.6 + _rng.nextDouble() * 1.4;
      final drop = LootDrop(d, at.clone(), Vector2(math.cos(a), math.sin(a)) * speed);
      switch (d.kind) {
        case DropKind.item:
          final item = d.item!;
          drop.rarity = item.rarity;
          drop.beamColor = _rarityColor(item.rarity);
          drop.icon = _icons[item.legendaryId != null ? data.legendaries[item.legendaryId]!.icon : data.bases[item.baseId]!.icon];
        case DropKind.material:
          drop.icon = _icons[data.materials[d.material]!.icon];
        case DropKind.shinyBits:
          drop.icon = _icons['currency_shiny_bits'];
        default:
          break;
      }
      entityLayer.add(drop);
    }
  }

  Color _rarityColor(String rarity) {
    final hex = data.rarity(rarity).color.replaceFirst('#', '');
    return Color(0xff000000 | int.parse(hex, radix: 16));
  }

  void collectDrop(LootDrop d) {
    final inv = profile.inventory;
    switch (d.drop.kind) {
      case DropKind.gold:
        inv.gold += d.drop.amount;
        floatText(hero, '+${d.drop.amount}g', const Color(0xffffd23f), size: 16, offsetY: 18);
      case DropKind.item:
        final item = d.drop.item!;
        if (!inv.addItem(item)) {
          if (frameCounter % 60 == 0) session.toast('Bag is full! Salvage or sell something.');
          return;
        }
        session.toast(
          item.name,
          rarity: item.rarity,
          icon: item.legendaryId != null ? data.legendaries[item.legendaryId]!.icon : data.bases[item.baseId]!.icon,
        );
        if (item.rarity == 'legendary') session.showBanner('LEGENDARY!', subtitle: item.name, style: 'legendary');
        session.bumpInventory();
        saveSoon();
      case DropKind.material:
        inv.addMaterial(d.drop.material!, d.drop.amount);
        session.toast('+${d.drop.amount} ${data.materials[d.drop.material]!.name}', icon: data.materials[d.drop.material]!.icon);
        final changed = quests.onMaterials(inv);
        if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
        session.bumpInventory();
      case DropKind.shinyBits:
        inv.shinyBits += d.drop.amount;
        session.toast('+${d.drop.amount} Shiny Bits', icon: 'currency_shiny_bits', color: 0xffff4bc8);
      case DropKind.healthOrb:
        combat.heal(hero, hero.maxHp * data.healthOrb.heal);
    }
    d.collected = true;
    d.despawn();
  }

  void grantItem(ItemInstance item) {
    if (!profile.inventory.addItem(item)) {
      // Bag full: drop it at the hero's feet instead of losing it.
      final drop = LootDrop(Drop.item(item), hero.ground.clone(), Vector2.zero())
        ..rarity = item.rarity
        ..beamColor = _rarityColor(item.rarity)
        ..icon = _icons[data.bases[item.baseId]!.icon];
      entityLayer.add(drop);
      session.toast('Bag full - ${item.name} dropped at your feet');
      return;
    }
    session.toast(item.name, rarity: item.rarity, icon: item.legendaryId != null ? data.legendaries[item.legendaryId]!.icon : data.bases[item.baseId]!.icon);
    if (item.rarity == 'legendary') session.showBanner('LEGENDARY!', subtitle: item.name, style: 'legendary');
    session.bumpInventory();
  }

  void completeGather(ResourceNodeEntity node) {
    final def = node.def;
    final job = data.dayJobs[def.skill]!;
    final progress = profile.dayJob(job.id);
    var amount = def.amount.$1.toInt() + _rng.nextInt(def.amount.$2.toInt() - def.amount.$1.toInt() + 1);
    if (_rng.nextDouble() < job.doubleChancePerLevel * (progress.level - 1)) amount *= 2;
    profile.inventory.addMaterial(def.item, amount);
    node.deplete();
    final mat = data.materials[def.item]!;
    session.toast('+$amount ${mat.name}', icon: mat.icon);
    floatText(hero, '+$amount ${mat.name}', const Color(0xffffe9a8), size: 16);
    // Day job XP.
    if (progress.level < job.maxLevel) {
      progress.xp += def.xp;
      while (progress.level < job.maxLevel && progress.xp >= job.xpToNext(progress.level)) {
        progress.xp -= job.xpToNext(progress.level);
        progress.level++;
        session.toast('${job.name} is now level ${progress.level}!', icon: job.icon, color: 0xff82f16d);
      }
    }
    final changed = quests.onMaterials(profile.inventory);
    if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
    session.bumpInventory();
  }

  void openChest(ChestEntity chest) {
    profile.opened.add(chest.placed.name);
    dropLoot(chest.lootTable, at: chest.ground + Vector2(0.4, 0.4), level: math.max(profile.level, 5));
    particles.emit(
      x: chest.position.x,
      y: chest.position.y - 30,
      color: const Color(0xffffd75e),
      count: 24,
      speed: 200,
      life: 0.8,
      size: 4,
      gravity: 200,
      upBias: 150,
    );
    final changed = quests.onOpen(chest.placed.name);
    if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
    saveSoon();
  }

  void discoverWaypoint(WaypointEntity wp) {
    profile.waypoints.add(wp.waypointId);
    profile.lastWaypoint = wp.waypointId;
    profile.potionCharges = profile.potionMax;
    session.showBanner('WAYPOINT ATTUNED', subtitle: wp.waypointName, style: 'quest');
    particles.ring(wp.position.x, wp.position.y, const Color(0xff6ff3ff), size: 110);
    final changed = quests.onDiscover(wp.waypointId);
    if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
    saveSoon();
  }

  void openWaypointPicker(WaypointEntity wp) {
    profile.lastWaypoint = wp.waypointId;
    profile.potionCharges = profile.potionMax;
    session.waypointPicker.value = true;
    setPaused(true);
  }

  void talkTo(NpcEntity npc) => questDirector.talk(npc);

  void reportEvent(String eventId) {
    final changed = quests.onEvent(eventId);
    if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
  }

  void onQuestsChanged(List<String> ids, {bool progressToast = false}) {
    if (progressToast) {
      for (final id in ids) {
        final q = data.quest(id);
        final s = quests.state(id);
        if (s.status == QuestStatus.ready) {
          session.toast('${q.name}: complete! Return to ${data.npcs[q.giver]!.name}', color: 0xffffc94f, icon: 'interact_talk');
        } else {
          for (var i = 0; i < q.objectives.length; i++) {
            final o = q.objectives[i];
            if (s.counts[i] > 0 && s.counts[i] <= o.count && o.count > 1) {
              session.toast('${o.text}: ${s.counts[i]}/${o.count}');
              break;
            }
          }
        }
      }
    }
    _refreshMarkers();
    _syncTracker();
    session.bumpQuests();
  }

  void _refreshMarkers() {
    for (final npc in npcs) {
      final q = quests.focusFor(npc.def.id);
      if (q == null) {
        npc.marker = null;
        continue;
      }
      npc.marker = switch (quests.status(q.id)) {
        QuestStatus.ready => '?',
        QuestStatus.available => '!',
        _ => null,
      };
    }
  }

  void _updateAreas() {
    if (frameCounter % 10 != 0) return;
    String? area;
    for (final o in map.objectsOfType('area')) {
      if (o.contains(hero.ground)) area = o.name;
    }
    if (area != null && area != _currentArea) {
      _currentArea = area;
      final o = map.object('area', area)!;
      session.areaName.value = o.prop('title') ?? area;
      session.showBanner((o.prop('title') ?? area).toUpperCase(), subtitle: o.prop('subtitle'), style: 'area');
    }
    for (final o in map.objectsOfType('trigger')) {
      final target = o.prop('discover');
      if (target == null || _discoveredTriggers.contains(target) || !o.contains(hero.ground)) continue;
      _discoveredTriggers.add(target);
      profile.discovered.add(target);
      final changed = quests.onDiscover(target);
      if (changed.isNotEmpty) onQuestsChanged(changed, progressToast: true);
    }
  }

  // ---------------------------------------------------------------------------
  // HUD sync
  // ---------------------------------------------------------------------------

  void _syncTracker() {
    session.tracker.value = [
      for (final q in quests.tracked)
        QuestTrackerEntry(
          q.id,
          q.name,
          [for (var i = 0; i < q.objectives.length; i++) TrackerObjective(q.objectives[i].text, quests.state(q.id).counts[i], q.objectives[i].count)],
          ready: quests.status(q.id) == QuestStatus.ready,
          giverName: data.npcs[q.giver]!.name,
        ),
    ];
  }

  AbilityHud _hud(AbilitySlotId slot, AbilityDef a, int unlockLevel) {
    final remaining = hero.cooldownOf(a.id);
    final cd = a.isUltimate ? hero.ultimateMax : a.cooldown * (1 - hero.stats.cooldownReduction);
    final unlocked = hero.unlocked(slot);
    return AbilityHud(
      slot: slot,
      abilityId: a.id,
      name: a.name,
      icon: a.icon ?? 'ability_quick_shot',
      description: a.description,
      cooldown: cd,
      remaining: a.isUltimate ? hero.ultimateMax - hero.ultimate : remaining,
      unlocked: unlocked,
      unlockLevel: unlockLevel,
      isUltimate: a.isUltimate,
      ready: unlocked && remaining <= 0 && (!a.isUltimate || hero.ultimateReady),
      aim: a.aim,
      range: a.range,
      radius: a.radius,
    );
  }

  void _syncHud({bool force = false}) {
    final s = session;
    s.hp.value = hero.hp;
    s.maxHp.value = hero.maxHp;
    s.level.value = profile.level;
    s.xpFraction.value = (profile.xp / hero.xpToNext).clamp(0, 1);
    s.gold.value = profile.inventory.gold;
    s.shinyBits.value = profile.inventory.shinyBits;
    s.ultimateCharge.value = hero.ultimate / hero.ultimateMax;
    s.abilities.value = [for (final slot in hero.slots) _hud(slot.slot, slot.ability, slot.unlockLevel)];
    final dodge = hero.dodgeAbility;
    if (dodge != null) s.dodge.value = _hud(AbilitySlotId.dodge, dodge, 1);
    s.potion.value = (profile.potionCharges, profile.potionMax, hero.potionCooldown / data.potion.cooldown);
    if (s.death.value == null) s.mood.value = hero.mood;
    if (force) _syncTracker();
  }

  // ---------------------------------------------------------------------------
  // GameCommands
  // ---------------------------------------------------------------------------

  @override
  void chooseDialogOption(String id) => questDirector.choose(id);

  @override
  void closeDialog() => questDirector.close();

  @override
  void equip(ItemInstance item) {
    final base = data.bases[item.baseId]!;
    if (!base.usableBy(profile.heroClass)) {
      session.toast('${data.heroes[profile.heroClass]!.name}s can\'t use that.');
      return;
    }
    profile.inventory.equip(item, data);
    hero.recomputeStats();
    session.bumpInventory();
    _syncHud();
    saveSoon();
  }

  @override
  void unequip(String slot) {
    if (profile.inventory.unequip(slot)) {
      hero.recomputeStats();
      session.bumpInventory();
      _syncHud();
    }
  }

  @override
  void salvage(ItemInstance item) {
    final bits = profile.inventory.salvage(item, data);
    session.toast(bits > 0 ? 'Salvaged into $bits Shiny Bits' : 'Salvaged. It was mostly lint.', icon: 'currency_shiny_bits');
    session.bumpInventory();
    _syncHud();
    saveSoon();
  }

  @override
  void sell(ItemInstance item) {
    final gold = profile.inventory.sell(item, data);
    session.toast('Sold for $gold gold', icon: 'currency_gold', color: 0xffffc94f);
    session.bumpInventory();
    _syncHud();
    saveSoon();
  }

  @override
  void travelTo(String waypointId) {
    session.waypointPicker.value = false;
    if (!profile.waypoints.contains(waypointId)) return;
    hero.cancelGather();
    hero.ground.setFrom(_waypointSpawn(waypointId));
    hero.syncScreenPosition();
    hero.knockback.setZero();
    profile.lastWaypoint = waypointId;
    profile.potionCharges = profile.potionMax;
    spawns.resetAggro();
    camera.viewfinder.position = hero.position.clone();
    particles.ring(hero.position.x, hero.position.y, const Color(0xff6ff3ff), size: 90);
    setPaused(false);
    saveSoon();
  }

  @override
  void respawn() {
    session.death.value = null;
    bosses.onHeroDied();
    spawns.resetAggro();
    hero
      ..dead = false
      ..deadTime = 0
      ..invulnerable = 2;
    hero.statuses.clear();
    hero.recomputeStats(fullHeal: true);
    hero.ground.setFrom(_waypointSpawn(profile.lastWaypoint));
    hero.syncScreenPosition();
    hero.playAnim('idle', restart: true);
    profile.potionCharges = profile.potionMax;
    camera.viewfinder.position = hero.position.clone();
    _syncHud(force: true);
    saveSoon();
  }

  @override
  void setPaused(bool value) {
    paused = value;
    if (value) input.clear();
  }

  @override
  void setDifficulty(String id) {
    if (!profile.unlockedDifficulties(data).any((d) => d.id == id)) return;
    profile.difficulty = id;
    session.showBanner(difficulty.name.toUpperCase(), subtitle: difficulty.tagline, style: 'danger');
    // Respawn regular packs so the new rules apply right away.
    for (final z in spawns.zones) {
      for (final m in z.members) {
        if (m.alive) m.despawn();
      }
      z.members.clear();
      z.timer = 0;
    }
    saveSoon();
  }

  void saveSoon() => _saveRequested = true;

  @override
  Future<void> saveNow() => saves.saveHero(profile);

  @override
  String questStatusLabel(String questId) => switch (quests.status(questId)) {
    QuestStatus.ready => 'Ready to turn in',
    QuestStatus.active => 'In progress',
    QuestStatus.completed => 'Completed',
    QuestStatus.available => 'Available',
    QuestStatus.locked => 'Locked',
  };
}
