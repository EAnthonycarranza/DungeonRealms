import 'dart:math' as math;

import '../content/game_data.dart';
import 'items.dart';

/// Final combat stats for a hero after level, gear and buffs.
class HeroStats {
  const HeroStats({
    required this.maxHp,
    required this.attack,
    required this.armor,
    required this.critChance,
    required this.critDamage,
    required this.attackSpeed,
    required this.moveSpeed,
    required this.cooldownReduction,
    required this.hpRegen,
    required this.damageBonus,
    required this.goldFind,
    required this.ultimateCharge,
  });

  final double maxHp;
  final double attack;
  final double armor;

  /// 0..1
  final double critChance;

  /// Extra damage on crit (0.6 = 160% damage).
  final double critDamage;

  /// Multiplier (1.0 = base rate).
  final double attackSpeed;

  /// Tiles per second.
  final double moveSpeed;

  /// 0..0.4
  final double cooldownReduction;
  final double hpRegen;
  final double damageBonus;
  final double goldFind;
  final double ultimateCharge;

  /// Stats that add together; attackSpeed and moveSpeed multiply the base.
  static HeroStats compute(HeroDef hero, int level, Iterable<ItemInstance> gear) {
    double base(String k) => (hero.baseStats[k] ?? 0) + (hero.growth[k] ?? 0) * (level - 1);
    final bonus = <String, double>{};
    for (final item in gear) {
      item.stats.forEach((k, v) => bonus[k] = (bonus[k] ?? 0) + v);
    }
    double add(String k) => base(k) + (bonus[k] ?? 0);
    return HeroStats(
      maxHp: add('maxHp'),
      attack: add('attack'),
      armor: add('armor'),
      critChance: math.min(0.75, add('critChance')),
      critDamage: add('critDamage'),
      attackSpeed: base('attackSpeed') * (1 + (bonus['attackSpeed'] ?? 0)),
      moveSpeed: base('moveSpeed') * (1 + math.min(0.5, bonus['moveSpeed'] ?? 0)),
      cooldownReduction: math.min(0.4, add('cooldownReduction')),
      hpRegen: add('hpRegen'),
      damageBonus: add('damageBonus'),
      goldFind: add('goldFind'),
      ultimateCharge: add('ultimateCharge'),
    );
  }
}

/// Shared damage math (heroes and enemies use the same formula).
class DamageMath {
  const DamageMath(this.progression);

  final ProgressionDef progression;

  /// Fraction of damage that gets through [armor] from an attacker of
  /// [attackerLevel].
  double mitigation(double armor, int attackerLevel) {
    final k = progression.armorBase + progression.armorPerAttackerLevel * attackerLevel;
    return 1 - armor / (armor + k);
  }

  double xpToNext(int level) => (progression.xpBase * math.pow(level, progression.xpExponent)).roundToDouble();
}
