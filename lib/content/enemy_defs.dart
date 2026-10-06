import 'json_reader.dart';

class EnemyPhaseDef {
  EnemyPhaseDef.fromJson(JsonReader j) : from = j.dbl('from'), onEnter = j.strOr('onEnter'), abilities = j.strings('abilities');

  /// Phase starts when health fraction drops to or below this value.
  final double from;
  final String? onEnter;
  final List<String> abilities;
}

class EnemyStats {
  EnemyStats.fromJson(JsonReader j) : hp = j.dbl('hp'), attack = j.dbl('attack'), armor = j.dbl('armor'), speed = j.dbl('speed'), radius = j.dbl('radius');

  final double hp, attack, armor, speed, radius;
}

class EnemyDef {
  EnemyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      title = j.strOr('title'),
      tags = j.strings('tags'),
      rank = j.strOr('rank', 'normal')!,
      sprite = j.str('sprite'),
      tint = j.strOr('tint'),
      stats = EnemyStats.fromJson(j.obj('stats')),
      xp = j.dbl('xp'),
      ai = j.str('ai'),
      aggroRange = j.dblOr('aggroRange', 7),
      leashRange = j.dblOr('leashRange', 16),
      preferredRange = j.dblOr('preferredRange', 0),
      abilities = j.strings('abilities'),
      phases = [for (final p in j.objects('phases')) EnemyPhaseDef.fromJson(p)],
      loot = j.strOr('loot'),
      barks = j.strings('barks'),
      deathBark = j.strOr('deathBark');

  final String id;
  final String name;
  final String? title;
  final List<String> tags;

  /// normal | elite | boss
  final String rank;
  final String sprite;
  final String? tint;
  final EnemyStats stats;
  final double xp;

  /// melee | ranged | caster | phased
  final String ai;
  final double aggroRange;
  final double leashRange;
  final double preferredRange;
  final List<String> abilities;
  final List<EnemyPhaseDef> phases;
  final String? loot;
  final List<String> barks;
  final String? deathBark;

  bool get isBoss => rank == 'boss';
  bool get isElite => rank == 'elite';

  /// Every ability this enemy can use, across phases.
  Iterable<String> get allAbilities sync* {
    yield* abilities;
    for (final p in phases) {
      yield* p.abilities;
      if (p.onEnter != null) yield p.onEnter!;
    }
  }
}

class EnemyScaling {
  EnemyScaling.fromJson(JsonReader j)
    : hpPerLevel = j.dbl('hpPerLevel'),
      attackPerLevel = j.dbl('attackPerLevel'),
      armorPerLevel = j.dbl('armorPerLevel'),
      xpPerLevel = j.dbl('xpPerLevel');

  final double hpPerLevel, attackPerLevel, armorPerLevel, xpPerLevel;

  double hp(double base, int level) => base * (1 + hpPerLevel * (level - 1));
  double attack(double base, int level) => base * (1 + attackPerLevel * (level - 1));
  double armor(double base, int level) => base + armorPerLevel * (level - 1);
  double xp(double base, int level) => base * (1 + xpPerLevel * (level - 1));
}

class PackMember {
  PackMember.fromJson(JsonReader j) : enemy = j.str('enemy'), count = j.intOr('count', 1);

  final String enemy;
  final int count;
}

class PackDef {
  PackDef.fromJson(JsonReader j) : id = j.str('id'), members = [for (final m in j.objects('members')) PackMember.fromJson(m)];

  final String id;
  final List<PackMember> members;

  Iterable<String> get enemyIds sync* {
    for (final m in members) {
      for (var i = 0; i < m.count; i++) {
        yield m.enemy;
      }
    }
  }
}
