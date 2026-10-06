import 'json_reader.dart';

class ChanceRange {
  ChanceRange.fromJson(JsonReader j)
    : chance = j.dblOr('chance', 1),
      range = j.has('range') ? j.range('range') : j.range('amount'),
      perLevel = j.dblOr('perLevel', 0);

  final double chance;
  final (double, double) range;
  final double perLevel;
}

class MaterialDrop {
  MaterialDrop.fromJson(JsonReader j) : item = j.str('item'), chance = j.dblOr('chance', 1), amount = j.range('amount');

  final String item;
  final double chance;
  final (double, double) amount;
}

class ItemRolls {
  ItemRolls.fromJson(JsonReader j) : rolls = j.intOr('rolls', 1), chance = j.dblOr('chance', 1), rarityWeights = j.doubleMap('rarityWeights');

  final int rolls;
  final double chance;

  /// Overrides the global rarity weights when non-empty.
  final Map<String, double> rarityWeights;
}

class UniqueDrop {
  UniqueDrop.fromJson(JsonReader j) : chance = j.dblOr('chance', 1), pool = j.strings('pool');

  final double chance;
  final List<String> pool;
}

class LootTableDef {
  LootTableDef.fromJson(JsonReader j)
    : id = j.str('id'),
      gold = j.has('gold') ? ChanceRange.fromJson(j.obj('gold')) : null,
      items = j.has('items') ? ItemRolls.fromJson(j.obj('items')) : null,
      unique = j.has('unique') ? UniqueDrop.fromJson(j.obj('unique')) : null,
      materials = [for (final m in j.objects('materials')) MaterialDrop.fromJson(m)],
      healthOrb = j.dblOr('healthOrb', 0),
      shinyBits = j.has('shinyBits') ? ChanceRange.fromJson(j.obj('shinyBits')) : null;

  final String id;
  final ChanceRange? gold;
  final ItemRolls? items;
  final UniqueDrop? unique;
  final List<MaterialDrop> materials;
  final double healthOrb;
  final ChanceRange? shinyBits;
}
