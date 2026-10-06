import 'dart:math' as math;

import '../content/game_data.dart';

/// A concrete, rolled item. Immutable; serialisable for saves.
class ItemInstance {
  const ItemInstance({
    required this.uid,
    required this.baseId,
    required this.rarity,
    required this.level,
    required this.name,
    required this.stats,
    this.legendaryId,
    this.affixIds = const [],
  });

  final String uid;
  final String baseId;
  final String? legendaryId;
  final String rarity;
  final int level;
  final String name;

  /// Rolled stats (implicit + affixes + legendary fixed stats).
  final Map<String, double> stats;
  final List<String> affixIds;

  bool get isLegendary => legendaryId != null;

  Map<String, Object?> toJson() => {
    'uid': uid,
    'base': baseId,
    if (legendaryId != null) 'legendary': legendaryId,
    'rarity': rarity,
    'level': level,
    'name': name,
    'stats': stats,
    if (affixIds.isNotEmpty) 'affixes': affixIds,
  };

  factory ItemInstance.fromJson(Map<String, Object?> j) => ItemInstance(
    uid: j['uid']! as String,
    baseId: j['base']! as String,
    legendaryId: j['legendary'] as String?,
    rarity: j['rarity']! as String,
    level: (j['level']! as num).toInt(),
    name: j['name']! as String,
    stats: {for (final e in (j['stats']! as Map).entries) e.key as String: (e.value as num).toDouble()},
    affixIds: [for (final a in (j['affixes'] as List?) ?? const []) a as String],
  );
}

/// Rolls items from content definitions. All randomness goes through [rng]
/// so tests can seed it.
class ItemFactory {
  ItemFactory(this.data, [math.Random? rng]) : rng = rng ?? math.Random();

  final GameData data;
  final math.Random rng;
  static int _counter = 0;

  String _uid() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_counter++).toRadixString(36)}-${rng.nextInt(1 << 30).toRadixString(36)}';

  double _roll(double min, double max) => min + rng.nextDouble() * (max - min);

  double _round(String stat, double v) {
    final def = data.stats[stat];
    if (def != null && def.isPercent) return (v * 1000).roundToDouble() / 1000;
    return v.roundToDouble();
  }

  /// Picks a rarity id using [weights] (or the global weights) shifted toward
  /// rarer results by [bonus] (difficulty / magic find).
  String rollRarity({Map<String, double> weights = const {}, double bonus = 0}) {
    final entries = <(String, double)>[];
    for (var i = 0; i < data.rarities.length; i++) {
      final r = data.rarities[i];
      var w = weights.isEmpty ? r.weight : (weights[r.id] ?? 0);
      // Each rarity tier above common is boosted by (1 + bonus)^tier.
      w *= math.pow(1 + bonus, i).toDouble();
      if (w > 0) entries.add((r.id, w));
    }
    final total = entries.fold<double>(0, (s, e) => s + e.$2);
    var pick = rng.nextDouble() * total;
    for (final (id, w) in entries) {
      pick -= w;
      if (pick <= 0) return id;
    }
    return entries.last.$1;
  }

  List<ItemBaseDef> _basesFor(int level, String heroClass, {String? slot}) => [
    for (final b in data.bases.values)
      if (b.dropsAt(level) && b.usableBy(heroClass) && (slot == null || b.slot == slot)) b,
  ];

  /// Rolls a random item. Legendary rarity picks from the legendary list.
  ItemInstance roll({
    required int level,
    required String heroClass,
    String? rarity,
    String? baseId,
    Map<String, double> rarityWeights = const {},
    double rarityBonus = 0,
  }) {
    final r = rarity ?? rollRarity(weights: rarityWeights, bonus: rarityBonus);
    if (r == 'legendary' && baseId == null) {
      final pool = [
        for (final l in data.legendaries.values)
          if (data.bases[l.base]!.usableBy(heroClass) && l.level <= level + 2) l,
      ];
      if (pool.isNotEmpty) return legendary(pool[rng.nextInt(pool.length)].id, level);
    }
    final candidates = baseId != null ? [data.bases[baseId]!] : _basesFor(level, heroClass);
    final base = candidates.isEmpty ? data.bases.values.first : candidates[rng.nextInt(candidates.length)];
    final rarityDef = data.rarity(r == 'legendary' ? 'epic' : r);
    final stats = <String, double>{};
    final implicit = base.implicit;
    stats[implicit.stat] = _round(implicit.stat, _roll(implicit.min(level), implicit.max(level)) * rarityDef.statMult);

    final pool = [
      for (final a in data.affixes)
        if (a.slots.contains(base.slot)) a,
    ]..shuffle(rng);
    final chosen = pool.take(rarityDef.affixes).toList();
    for (final a in chosen) {
      final v = _roll(a.min(level), a.max(level));
      stats[a.stat] = _round(a.stat, (stats[a.stat] ?? 0) + v);
    }
    return ItemInstance(
      uid: _uid(),
      baseId: base.id,
      rarity: rarityDef.id,
      level: level,
      name: _name(base, rarityDef.id, chosen),
      stats: stats,
      affixIds: [for (final a in chosen) a.id],
    );
  }

  ItemInstance legendary(String id, int level) {
    final def = data.legendaries[id]!;
    final base = data.bases[def.base]!;
    final lvl = math.max(level, def.level);
    final stats = <String, double>{};
    final implicit = base.implicit;
    stats[implicit.stat] = _round(implicit.stat, implicit.max(lvl) * data.rarity('legendary').statMult);
    def.fixed.forEach((stat, value) {
      // Fixed stats roll within +-10% so two drops are never identical.
      stats[stat] = _round(stat, (stats[stat] ?? 0) + value * (0.9 + rng.nextDouble() * 0.2));
    });
    return ItemInstance(uid: _uid(), baseId: base.id, legendaryId: id, rarity: 'legendary', level: lvl, name: def.name, stats: stats);
  }

  String _name(ItemBaseDef base, String rarity, List<AffixDef> affixes) {
    switch (rarity) {
      case 'uncommon':
        return affixes.isEmpty ? base.name : '${affixes.first.prefix} ${base.name}';
      case 'rare':
        if (affixes.length < 2) return base.name;
        return '${affixes[0].prefix} ${base.name} ${affixes[1].suffix}';
      case 'epic':
        final adj = data.epicNames.adjectives[rng.nextInt(data.epicNames.adjectives.length)];
        final noun = data.epicNames.nouns[rng.nextInt(data.epicNames.nouns.length)];
        return '$adj ${base.name} of $noun';
      default:
        return base.name;
    }
  }
}

/// Rough single-number item score used for "upgrade" arrows in the UI.
double itemScore(ItemInstance item) {
  const weights = {
    'attack': 3.0,
    'maxHp': 0.5,
    'armor': 0.9,
    'hpRegen': 4.0,
    'critChance': 300.0,
    'critDamage': 60.0,
    'attackSpeed': 220.0,
    'moveSpeed': 200.0,
    'cooldownReduction': 220.0,
    'damageBonus': 260.0,
    'goldFind': 20.0,
    'ultimateCharge': 60.0,
  };
  var score = 0.0;
  item.stats.forEach((k, v) => score += (weights[k] ?? 1) * v);
  if (item.isLegendary) score += 40;
  return score;
}
