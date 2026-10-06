import 'dart:math' as math;

import '../content/game_data.dart';
import 'items.dart';

enum DropKind { gold, item, material, shinyBits, healthOrb }

class Drop {
  const Drop.gold(this.amount) : kind = DropKind.gold, item = null, material = null;
  const Drop.item(ItemInstance this.item) : kind = DropKind.item, amount = 1, material = null;
  const Drop.material(String this.material, this.amount) : kind = DropKind.material, item = null;
  const Drop.shinyBits(this.amount) : kind = DropKind.shinyBits, item = null, material = null;
  const Drop.healthOrb() : kind = DropKind.healthOrb, amount = 1, item = null, material = null;

  final DropKind kind;
  final int amount;
  final ItemInstance? item;
  final String? material;
}

/// Rolls loot tables into concrete drops.
class LootRoller {
  LootRoller(this.data, this.items, [math.Random? rng]) : rng = rng ?? math.Random();

  final GameData data;
  final ItemFactory items;
  final math.Random rng;

  int _range((double, double) r, [double perLevel = 0, int level = 1]) {
    final lo = r.$1 + perLevel * (level - 1);
    final hi = r.$2 + perLevel * (level - 1);
    return (lo + rng.nextDouble() * (hi - lo)).round();
  }

  List<Drop> roll(String tableId, {required int level, required String heroClass, DifficultyDef? difficulty, double goldFind = 0}) {
    final table = data.lootTables[tableId];
    if (table == null) return const [];
    final drops = <Drop>[];
    final gold = table.gold;
    if (gold != null && rng.nextDouble() < gold.chance) {
      final amount = (_range(gold.range, gold.perLevel, level) * (difficulty?.gold ?? 1) * (1 + goldFind)).round();
      if (amount > 0) drops.add(Drop.gold(amount));
    }
    final rolls = table.items;
    if (rolls != null) {
      for (var i = 0; i < rolls.rolls; i++) {
        if (rng.nextDouble() >= rolls.chance) continue;
        drops.add(Drop.item(items.roll(level: level, heroClass: heroClass, rarityWeights: rolls.rarityWeights, rarityBonus: difficulty?.rarityBonus ?? 0)));
      }
    }
    final unique = table.unique;
    if (unique != null && unique.pool.isNotEmpty && rng.nextDouble() < unique.chance) {
      drops.add(Drop.item(items.legendary(unique.pool[rng.nextInt(unique.pool.length)], level)));
    }
    for (final m in table.materials) {
      if (rng.nextDouble() < m.chance) {
        final n = _range(m.amount);
        if (n > 0) drops.add(Drop.material(m.item, n));
      }
    }
    final bits = table.shinyBits;
    if (bits != null && rng.nextDouble() < bits.chance) {
      final n = _range(bits.range);
      if (n > 0) drops.add(Drop.shinyBits(n));
    }
    if (rng.nextDouble() < table.healthOrb) drops.add(const Drop.healthOrb());
    return drops;
  }
}
