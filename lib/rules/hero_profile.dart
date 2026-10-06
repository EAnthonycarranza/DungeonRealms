import '../content/game_data.dart';
import 'inventory.dart';
import 'items.dart';
import 'quest_log.dart';

class DayJobProgress {
  DayJobProgress({this.level = 1, this.xp = 0});

  int level;
  double xp;

  Map<String, Object?> toJson() => {'level': level, 'xp': xp};

  factory DayJobProgress.fromJson(Map<String, Object?> j) =>
      DayJobProgress(level: ((j['level'] as num?) ?? 1).toInt(), xp: ((j['xp'] as num?) ?? 0).toDouble());
}

/// Everything persistent about one hero. This is what a save slot stores
/// (locally today, in Supabase later - see docs/ROADMAP.md, Phase 04).
class HeroProfile {
  HeroProfile({
    required this.id,
    required this.heroClass,
    required this.look,
    this.level = 1,
    this.xp = 0,
    Inventory? inventory,
    Map<String, QuestState>? quests,
    Set<String>? waypoints,
    Map<String, DayJobProgress>? dayJobs,
    this.potionMax = 3,
    this.potionCharges = 3,
    this.difficulty = 'normal',
    Set<String>? bossKills,
    this.lastWaypoint = 'buckleburg_gate',
    this.playSeconds = 0,
    this.kills = 0,
    this.deaths = 0,
    this.region = 'goblinwood',
    Set<String>? discovered,
    Set<String>? opened,
    this.version = currentVersion,
  }) : inventory = inventory ?? Inventory(),
       quests = quests ?? {},
       waypoints = waypoints ?? {'buckleburg_gate'},
       dayJobs = dayJobs ?? {},
       bossKills = bossKills ?? {},
       discovered = discovered ?? {},
       opened = opened ?? {};

  static const currentVersion = 1;

  final String id;
  final String heroClass;
  final String look;
  int level;
  double xp;
  final Inventory inventory;

  /// Saved quest states (the live [QuestLog] writes back into this).
  Map<String, QuestState> quests;
  final Set<String> waypoints;
  final Map<String, DayJobProgress> dayJobs;
  int potionMax;
  int potionCharges;
  String difficulty;

  /// `<difficulty>:<boss id>` for every boss defeated.
  final Set<String> bossKills;
  String lastWaypoint;
  double playSeconds;
  int kills;
  int deaths;
  String region;
  final Set<String> discovered;

  /// One-time containers already looted.
  final Set<String> opened;
  final int version;

  DayJobProgress dayJob(String id) => dayJobs.putIfAbsent(id, DayJobProgress.new);

  /// Creates a brand-new level 1 hero with starting gear equipped.
  factory HeroProfile.create(GameData data, String heroClass, String look, ItemFactory items) {
    final hero = data.heroes[heroClass]!;
    final profile = HeroProfile(
      id: '${heroClass}_${DateTime.now().millisecondsSinceEpoch}',
      heroClass: heroClass,
      look: look,
      potionMax: data.potion.charges,
      potionCharges: data.potion.charges,
    );
    for (final g in hero.startingGear) {
      final item = g.unique != null ? items.legendary(g.unique!, 1) : items.roll(level: 1, heroClass: heroClass, rarity: g.rarity, baseId: g.base);
      profile.inventory.addItem(item);
      profile.inventory.equip(item, data);
    }
    profile.inventory.gold = 15;
    return profile;
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'id': id,
    'heroClass': heroClass,
    'look': look,
    'level': level,
    'xp': xp,
    'inventory': inventory.toJson(),
    'quests': {for (final e in quests.entries) e.key: e.value.toJson()},
    'waypoints': waypoints.toList(),
    'dayJobs': {for (final e in dayJobs.entries) e.key: e.value.toJson()},
    'potionMax': potionMax,
    'potionCharges': potionCharges,
    'difficulty': difficulty,
    'bossKills': bossKills.toList(),
    'lastWaypoint': lastWaypoint,
    'playSeconds': playSeconds,
    'kills': kills,
    'deaths': deaths,
    'region': region,
    'discovered': discovered.toList(),
    'opened': opened.toList(),
  };

  factory HeroProfile.fromJson(Map<String, Object?> j) {
    Set<String> strings(String k) => {for (final s in (j[k] as List?) ?? const []) s as String};
    return HeroProfile(
      id: j['id']! as String,
      heroClass: j['heroClass']! as String,
      look: j['look']! as String,
      level: ((j['level'] as num?) ?? 1).toInt(),
      xp: ((j['xp'] as num?) ?? 0).toDouble(),
      inventory: Inventory.fromJson(((j['inventory'] as Map?) ?? const {}).cast<String, Object?>()),
      quests: QuestLog.statesFromJson((j['quests'] as Map?)?.cast<String, Object?>()),
      waypoints: strings('waypoints'),
      dayJobs: {
        for (final e in ((j['dayJobs'] as Map?) ?? const {}).entries) e.key as String: DayJobProgress.fromJson((e.value as Map).cast<String, Object?>()),
      },
      potionMax: ((j['potionMax'] as num?) ?? 3).toInt(),
      potionCharges: ((j['potionCharges'] as num?) ?? 3).toInt(),
      difficulty: (j['difficulty'] as String?) ?? 'normal',
      bossKills: strings('bossKills'),
      lastWaypoint: (j['lastWaypoint'] as String?) ?? 'buckleburg_gate',
      playSeconds: ((j['playSeconds'] as num?) ?? 0).toDouble(),
      kills: ((j['kills'] as num?) ?? 0).toInt(),
      deaths: ((j['deaths'] as num?) ?? 0).toInt(),
      region: (j['region'] as String?) ?? 'goblinwood',
      discovered: strings('discovered'),
      opened: strings('opened'),
      version: ((j['version'] as num?) ?? 1).toInt(),
    );
  }

  /// Difficulties this hero may select.
  List<DifficultyDef> unlockedDifficulties(GameData data) => [
    for (final d in data.progression.difficulties)
      if (d.unlock == null || _unlockMet(d.unlock!)) d,
  ];

  bool _unlockMet(String unlock) {
    final parts = unlock.split(':');
    final key = parts.length == 1 ? 'normal:${parts[0]}' : unlock;
    return bossKills.contains(key);
  }
}
