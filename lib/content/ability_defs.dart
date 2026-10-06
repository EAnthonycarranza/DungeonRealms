import 'json_reader.dart';

/// Behaviours implemented in code (lib/game/combat/ability_runner.dart).
/// New abilities should reuse one of these; add a new behaviour only when no
/// combination of parameters can express the idea.
enum AbilityBehavior {
  projectile,
  projectileFan,
  groundArea,
  multiArea,
  dash,
  meleeArc,
  charge,
  healAllies,
  summon,
  buffSelf;

  static AbilityBehavior parse(String s) => switch (s) {
    'projectile' => projectile,
    'projectile_fan' => projectileFan,
    'ground_area' => groundArea,
    'multi_area' => multiArea,
    'dash' => dash,
    'melee_arc' => meleeArc,
    'charge' => charge,
    'heal_allies' => healAllies,
    'summon' => summon,
    'buff_self' => buffSelf,
    _ => throw FormatException('Unknown ability behavior "$s"'),
  };
}

/// How the player aims an ability (drives the touch drag indicator).
enum AimMode {
  direction,
  line,
  cone,
  ground,
  self;

  static AimMode parse(String s) => AimMode.values.firstWhere((m) => m.name == s, orElse: () => throw FormatException('Unknown aim mode "$s"'));
}

class ProjectileSpec {
  ProjectileSpec.fromJson(JsonReader j) : sprite = j.str('sprite'), speed = j.dbl('speed'), radius = j.dblOr('radius', 0.3), pierce = j.intOr('pierce', 0);

  final String sprite;
  final double speed;
  final double radius;

  /// Number of extra targets the projectile passes through (999 = all).
  final int pierce;
}

class StatusSpec {
  StatusSpec.fromJson(JsonReader j) : status = j.str('status'), duration = j.dbl('duration'), amount = j.dblOr('amount', 0);

  /// root | slow | stun | burn
  final String status;
  final double duration;
  final double amount;
}

class TelegraphSpec {
  TelegraphSpec.fromJson(JsonReader j) : shape = j.str('shape'), time = j.dbl('time');

  /// cone | circle | line
  final String shape;
  final double time;
}

class AbilityDef {
  AbilityDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      description = j.strOr('description', '')!,
      icon = j.strOr('icon'),
      behavior = AbilityBehavior.parse(j.str('behavior')),
      aim = AimMode.parse(j.strOr('aim', 'direction')!),
      target = j.strOr('target', 'aim')!,
      resource = j.strOr('resource', 'cooldown')!,
      cooldown = j.dblOr('cooldown', 1),
      castTime = j.dblOr('castTime', 0),
      animation = j.strOr('animation'),
      releaseAnimation = j.strOr('releaseAnimation'),
      range = j.dblOr('range', 6),
      autoTarget = j.dblOr('autoTarget', 0),
      damage = j.dblOr('damage', 0),
      tickDamage = j.dblOr('tickDamage', 0),
      projectile = j.has('projectile') ? ProjectileSpec.fromJson(j.obj('projectile')) : null,
      count = j.intOr('count', 1),
      spread = j.dblOr('spread', 0),
      radius = j.dblOr('radius', 0),
      delay = j.dblOr('delay', 0),
      duration = j.dblOr('duration', 0),
      tickInterval = j.dblOr('tickInterval', 0.5),
      visual = j.strOr('visual'),
      effects = [for (final e in j.objects('effects')) StatusSpec.fromJson(e)],
      knockback = j.dblOr('knockback', 0),
      arc = j.dblOr('arc', 90),
      width = j.dblOr('width', 1),
      speed = j.dblOr('speed', 0),
      wallStun = j.dblOr('wallStun', 0),
      distance = j.dblOr('distance', 0),
      invulnerable = j.boolOr('invulnerable', false),
      direction = j.strOr('direction', 'aim')!,
      amount = j.dblOr('amount', 0),
      condition = j.strOr('condition'),
      pack = j.strOr('pack'),
      bark = j.strOr('bark'),
      buff = j.doubleMap('buff'),
      includeSelf = j.boolOr('includeSelf', false),
      telegraph = j.has('telegraph') ? TelegraphSpec.fromJson(j.obj('telegraph')) : null,
      chargeGain = j.dblOr('chargeGain', 0);

  final String id;
  final String name;
  final String description;
  final String? icon;
  final AbilityBehavior behavior;
  final AimMode aim;

  /// `aim` (default) or `self` (area centred on the caster).
  final String target;

  /// `cooldown` or `ultimate` (needs a full ultimate meter).
  final String resource;
  final double cooldown;

  /// Wind-up before the effect happens (telegraph time for enemies).
  final double castTime;
  final String? animation;
  final String? releaseAnimation;
  final double range;

  /// Auto-aim radius for tap-to-cast; 0 disables auto-aim.
  final double autoTarget;

  /// Damage multiplier applied to the caster's attack.
  final double damage;
  final double tickDamage;
  final ProjectileSpec? projectile;
  final int count;

  /// Total cone angle in degrees for fans.
  final double spread;
  final double radius;
  final double delay;
  final double duration;
  final double tickInterval;
  final String? visual;
  final List<StatusSpec> effects;
  final double knockback;
  final double arc;
  final double width;
  final double speed;
  final double wallStun;
  final double distance;
  final bool invulnerable;
  final String direction;
  final double amount;
  final String? condition;
  final String? pack;
  final String? bark;
  final Map<String, double> buff;
  final bool includeSelf;
  final TelegraphSpec? telegraph;
  final double chargeGain;

  bool get isUltimate => resource == 'ultimate';
}
