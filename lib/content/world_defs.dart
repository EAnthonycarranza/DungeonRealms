import 'json_reader.dart';

class TerrainRule {
  TerrainRule.fromJson(this.id, JsonReader j) : walkable = j.boolOr('walkable', true);

  final String id;
  final bool walkable;
}

class WaypointDef {
  WaypointDef.fromJson(JsonReader j) : id = j.str('id'), name = j.str('name');

  final String id, name;
}

class RegionDef {
  RegionDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      levels = j.range('levels'),
      map = j.strOr('map'),
      playable = j.boolOr('playable', false),
      description = j.str('description'),
      ambient = j.strOr('ambient'),
      waypoints = [for (final w in j.objects('waypoints')) WaypointDef.fromJson(w)],
      startWaypoint = j.strOr('startWaypoint'),
      loadingTips = j.strings('loadingTips'),
      deathQuips = j.strings('deathQuips');

  final String id, name;
  final (double, double) levels;
  final String? map;
  final bool playable;
  final String description;

  /// Ambient effect over the camera view: `leaves` (or none).
  final String? ambient;
  final List<WaypointDef> waypoints;

  /// Where new heroes start (and the waypoint they know from the outset).
  final String? startWaypoint;

  /// Flavor for the loading screen and the death screen.
  final List<String> loadingTips, deathQuips;

  String get levelLabel => 'LEVEL ${levels.$1.toInt()}–${levels.$2.toInt()}';
}

class ResourceDef {
  ResourceDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      skill = j.str('skill'),
      verb = j.str('verb'),
      item = j.str('item'),
      amount = j.range('amount'),
      gatherTime = j.dbl('gatherTime'),
      respawn = j.dbl('respawn'),
      xp = j.dbl('xp'),
      prop = j.str('prop'),
      depletedProp = j.str('depletedProp'),
      icon = j.str('icon');

  final String id, name, skill, verb, item;
  final (double, double) amount;
  final double gatherTime, respawn, xp;
  final String prop, depletedProp, icon;
}

class DayJobDef {
  DayJobDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      icon = j.str('icon'),
      maxLevel = j.integer('maxLevel'),
      xpBase = j.dbl('xpBase'),
      speedPerLevel = j.dbl('speedPerLevel'),
      doubleChancePerLevel = j.dbl('doubleChancePerLevel'),
      flavor = j.str('flavor');

  final String id, name, icon;
  final int maxLevel;
  final double xpBase, speedPerLevel, doubleChancePerLevel;
  final String flavor;

  /// XP needed to go from [level] to level + 1.
  double xpToNext(int level) => xpBase * level * 1.5;
}

class EventWaveDef {
  EventWaveDef.fromJson(JsonReader j) : at = j.dbl('at'), pack = j.str('pack');

  final double at;
  final String pack;
}

class EventTargetDef {
  EventTargetDef.fromJson(JsonReader j) : name = j.str('name'), hp = j.dbl('hp'), radius = j.dbl('radius'), prop = j.str('prop');

  final String name;
  final double hp, radius;
  final String prop;
}

class EventDef {
  EventDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      description = j.str('description'),
      type = j.str('type'),
      zone = j.str('zone'),
      target = j.has('target') ? EventTargetDef.fromJson(j.obj('target')) : null,
      duration = j.dbl('duration'),
      level = j.integer('level'),
      waves = [for (final w in j.objects('waves')) EventWaveDef.fromJson(w)],
      spawnRadius = j.dbl('spawnRadius'),
      cooldown = j.dbl('cooldown'),
      loot = j.strOr('loot'),
      xp = j.intOr('xp', 0),
      npc = j.strOr('npc'),
      startPrompt = j.strOr('startPrompt'),
      runningText = j.strOr('runningText'),
      startBark = j.strOr('startBark'),
      successBark = j.strOr('successBark'),
      failBark = j.strOr('failBark');

  final String id, name, description, type, zone;
  final EventTargetDef? target;
  final double duration;
  final int level;
  final List<EventWaveDef> waves;
  final double spawnRadius, cooldown;
  final String? loot;
  final int xp;

  /// The NPC who shouts the start / success / fail barks.
  final String? npc;

  /// Dialog button that (re)starts the event, and what the quest giver says
  /// while it runs.
  final String? startPrompt, runningText;
  final String? startBark, successBark, failBark;
}

class PotionDef {
  PotionDef.fromJson(JsonReader j)
    : name = j.str('name'),
      icon = j.str('icon'),
      charges = j.integer('charges'),
      maxCharges = j.integer('maxCharges'),
      heal = j.dbl('heal'),
      cooldown = j.dbl('cooldown'),
      description = j.str('description');

  final String name, icon;
  final int charges, maxCharges;
  final double heal, cooldown;
  final String description;
}

class HealthOrbDef {
  HealthOrbDef.fromJson(JsonReader j) : heal = j.dbl('heal'), radius = j.dbl('radius'), lifetime = j.dbl('lifetime');

  final double heal, radius, lifetime;
}

class DifficultyDef {
  DifficultyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      icon = j.strOr('icon', '')!,
      tagline = j.str('tagline'),
      unlock = j.strOr('unlock'),
      hp = j.dbl('hp'),
      damage = j.dbl('damage'),
      xp = j.dbl('xp'),
      gold = j.dbl('gold'),
      rarityBonus = j.dbl('rarityBonus'),
      mechanics = j.strings('mechanics');

  final String id, name, icon, tagline;

  /// `<boss id>` (on normal) or `<difficulty>:<boss id>`.
  final String? unlock;
  final double hp, damage, xp, gold, rarityBonus;
  final List<String> mechanics;
}

class MechanicDef {
  MechanicDef.fromJson(JsonReader j) : id = j.str('id'), name = j.str('name'), description = j.str('description');

  final String id, name, description;
}

class ProgressionDef {
  ProgressionDef.fromJson(JsonReader j)
    : levelCap = j.integer('levelCap'),
      startingGold = j.intOr('startingGold', 0),
      xpBase = j.obj('xpCurve').dbl('base'),
      xpExponent = j.obj('xpCurve').dbl('exponent'),
      ultimateMax = j.obj('ultimate').dbl('max'),
      ultimateOnHurt = j.obj('ultimate').dbl('onHurt'),
      armorBase = j.obj('combat').dbl('armorBase'),
      armorPerAttackerLevel = j.obj('combat').dbl('armorPerAttackerLevel'),
      regenDelay = j.obj('combat').dbl('regenOutOfCombatDelay'),
      regenOutOfCombatPct = j.obj('combat').dbl('regenOutOfCombatPct'),
      difficulties = [for (final d in j.objects('difficulties')) DifficultyDef.fromJson(d)],
      mechanics = [for (final m in j.objects('mechanics')) MechanicDef.fromJson(m)];

  final int levelCap;
  final int startingGold;
  final double xpBase, xpExponent;
  final double ultimateMax, ultimateOnHurt;
  final double armorBase, armorPerAttackerLevel;
  final double regenDelay, regenOutOfCombatPct;
  final List<DifficultyDef> difficulties;
  final List<MechanicDef> mechanics;
}
