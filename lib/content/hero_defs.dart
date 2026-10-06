import 'json_reader.dart';

/// A face crop on a hero's concept-art sheet: centre (x, y) and radius, in
/// sheet pixels.
class PortraitCrop {
  const PortraitCrop(this.x, this.y, this.radius);
  final double x, y, radius;
}

class HeroLookDef {
  HeroLookDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      sprite = j.strOr('sprite'),
      sheet = j.str('sheet'),
      expressions = {
        for (final e in j.obj('expressions').json.entries)
          e.key: () {
            final v = (e.value as List).cast<num>();
            return PortraitCrop(v[0].toDouble(), v[1].toDouble(), v[2].toDouble());
          }(),
      };

  final String id;
  final String name;

  /// Character sprite sheet id (`assets/images/sprites/<sprite>.json`), only
  /// set for playable looks.
  final String? sprite;

  /// Concept art sheet under assets/images/.
  final String sheet;

  /// Expression name -> face crop. Known names: idle, stunned, attack,
  /// ultimate, panic.
  final Map<String, PortraitCrop> expressions;

  PortraitCrop crop(String expression) => expressions[expression] ?? expressions['idle'] ?? expressions.values.first;
}

class HeroAbilitySlot {
  HeroAbilitySlot.fromJson(JsonReader j) : abilityId = j.str('id'), unlockLevel = j.intOr('unlockLevel', 1), ultimate = j.boolOr('ultimate', false);

  final String abilityId;
  final int unlockLevel;
  final bool ultimate;
}

class GearGrant {
  GearGrant.fromJson(JsonReader j) : base = j.strOr('base'), rarity = j.strOr('rarity', 'common')!, unique = j.strOr('unique');

  final String? base;
  final String rarity;
  final String? unique;
}

class HeroDef {
  HeroDef.fromJson(JsonReader j)
    : id = j.str('id'),
      name = j.str('name'),
      kicker = j.str('kicker'),
      role = j.str('role'),
      description = j.str('description'),
      tone = j.strOr('tone', 'gold')!,
      playable = j.boolOr('playable', false),
      skillNames = j.strings('skills'),
      baseStats = j.doubleMap('baseStats'),
      growth = j.doubleMap('growth'),
      basicAbility = j.strOr('basicAbility'),
      dodgeAbility = j.strOr('dodgeAbility'),
      abilities = [for (final a in j.objects('abilities')) HeroAbilitySlot.fromJson(a)],
      startingGear = [for (final g in j.objects('startingGear')) GearGrant.fromJson(g)],
      looks = [for (final l in j.objects('looks')) HeroLookDef.fromJson(l)];

  final String id;
  final String name;
  final String kicker;
  final String role;
  final String description;
  final String tone;
  final bool playable;
  final List<String> skillNames;
  final Map<String, double> baseStats;
  final Map<String, double> growth;
  final String? basicAbility;
  final String? dodgeAbility;
  final List<HeroAbilitySlot> abilities;
  final List<GearGrant> startingGear;
  final List<HeroLookDef> looks;

  HeroLookDef look(String? id) => looks.firstWhere((l) => l.id == id, orElse: () => looks.first);
}
