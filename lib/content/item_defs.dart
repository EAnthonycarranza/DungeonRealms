import 'json_reader.dart';

class RarityDef {
  RarityDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      color = j.str('color'),
      affixes = j.integer('affixes'),
      weight = j.dbl('weight'),
      valueMult = j.dbl('valueMult'),
      salvage = j.integer('salvage'),
      statMult = j.dbl('statMult');

  final String id, name, color;
  final int affixes;
  final double weight;
  final double valueMult;
  final int salvage;
  final double statMult;
}

class SlotDef {
  SlotDef.fromJson(JsonReader j) : id = j.str('id'), name = j.str('name'), icon = j.str('icon');

  final String id, name, icon;
}

class StatDef {
  StatDef.fromJson(JsonReader j) : id = j.str('id'), name = j.str('name'), format = j.str('format');

  final String id, name;

  /// flat | flat_per_second | percent
  final String format;

  bool get isPercent => format == 'percent';
}

class StatRoll {
  StatRoll.fromJson(JsonReader j) : stat = j.str('stat'), range = j.range('range'), perLevel = j.dblOr('perLevel', 0);

  final String stat;
  final (double, double) range;
  final double perLevel;

  double min(int level) => range.$1 + perLevel * (level - 1);
  double max(int level) => range.$2 + perLevel * (level - 1);
}

class AffixDef extends StatRoll {
  AffixDef.fromJson(super.j) : id = j.str('id'), prefix = j.str('prefix'), suffix = j.str('suffix'), slots = j.strings('slots'), super.fromJson();

  final String id, prefix, suffix;
  final List<String> slots;
}

class ItemBaseDef {
  ItemBaseDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      slot = j.str('slot'),
      classes = j.strings('classes'),
      icon = j.str('icon'),
      levels = j.range('levels'),
      implicit = StatRoll.fromJson(j.obj('implicit'));

  final String id, name, slot;

  /// Hero classes that can equip it; empty = everyone.
  final List<String> classes;
  final String icon;
  final (double, double) levels;
  final StatRoll implicit;

  bool usableBy(String heroClass) => classes.isEmpty || classes.contains(heroClass);
  bool dropsAt(int level) => level >= levels.$1 && level <= levels.$2;
}

class PowerDef {
  PowerDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      ability = j.strOr('ability'),
      description = j.str('description'),
      params = j.doubleMap('params');

  /// Power id, looked up in lib/game/combat/powers.dart.
  final String id;
  final String name;

  /// The ability it changes; the hook only fires for that ability. Null
  /// means always active (e.g. damage reduction).
  final String? ability;
  final String description;
  final Map<String, double> params;

  double param(String key, double fallback) => params[key] ?? fallback;
}

class LegendaryDef {
  LegendaryDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      base = j.str('base'),
      icon = j.str('icon'),
      level = j.integer('level'),
      fixed = j.doubleMap('fixed'),
      power = PowerDef.fromJson(j.obj('power')),
      flavor = j.str('flavor');

  final String id, name, base, icon;
  final int level;
  final Map<String, double> fixed;
  final PowerDef power;
  final String flavor;
}

class MaterialDef {
  MaterialDef.fromJson(JsonReader j) : id = j.str('id'), name = j.str('name'), icon = j.str('icon'), description = j.str('description');

  final String id, name, icon;
  final String description;
}

class EpicNameParts {
  EpicNameParts.fromJson(JsonReader j) : adjectives = j.strings('adjectives'), nouns = j.strings('nouns');

  final List<String> adjectives, nouns;
}
