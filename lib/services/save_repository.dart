import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../rules/hero_profile.dart';

/// Persistence boundary for hero saves.
///
/// Phase 04 of the roadmap swaps [LocalSaveRepository] for a Supabase-backed
/// implementation; nothing else in the game should know where saves live.
abstract class SaveRepository {
  Future<List<HeroProfile>> listHeroes();
  Future<HeroProfile?> loadHero(String id);
  Future<void> saveHero(HeroProfile profile);
  Future<void> deleteHero(String id);

  Future<Map<String, Object?>> loadSettings();
  Future<void> saveSettings(Map<String, Object?> settings);
}

/// Saves to the device with shared_preferences (works on mobile and web).
class LocalSaveRepository implements SaveRepository {
  static const _indexKey = 'dr.heroes';
  static const _settingsKey = 'dr.settings';
  static String _heroKey(String id) => 'dr.hero.$id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<HeroProfile>> listHeroes() async {
    final prefs = await _prefs;
    final ids = prefs.getStringList(_indexKey) ?? const [];
    final heroes = <HeroProfile>[];
    for (final id in ids) {
      final hero = await loadHero(id);
      if (hero != null) heroes.add(hero);
    }
    return heroes;
  }

  @override
  Future<HeroProfile?> loadHero(String id) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_heroKey(id));
    if (raw == null) return null;
    try {
      return HeroProfile.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } on Object {
      // A corrupt save should never brick the title screen.
      return null;
    }
  }

  @override
  Future<void> saveHero(HeroProfile profile) async {
    final prefs = await _prefs;
    await prefs.setString(_heroKey(profile.id), jsonEncode(profile.toJson()));
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    if (!ids.contains(profile.id)) {
      // Most recent first.
      await prefs.setStringList(_indexKey, [profile.id, ...ids]);
    } else if (ids.first != profile.id) {
      await prefs.setStringList(_indexKey, [profile.id, ...ids.where((i) => i != profile.id)]);
    }
  }

  @override
  Future<void> deleteHero(String id) async {
    final prefs = await _prefs;
    await prefs.remove(_heroKey(id));
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    await prefs.setStringList(_indexKey, ids.where((i) => i != id).toList());
  }

  @override
  Future<Map<String, Object?>> loadSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> saveSettings(Map<String, Object?> settings) async {
    final prefs = await _prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }
}

/// In-memory implementation for tests.
class MemorySaveRepository implements SaveRepository {
  final _heroes = <String, Map<String, Object?>>{};
  Map<String, Object?> _settings = {};

  @override
  Future<List<HeroProfile>> listHeroes() async => [for (final j in _heroes.values) HeroProfile.fromJson(j)];

  @override
  Future<HeroProfile?> loadHero(String id) async {
    final j = _heroes[id];
    return j == null ? null : HeroProfile.fromJson(jsonDecode(jsonEncode(j)) as Map<String, Object?>);
  }

  @override
  Future<void> saveHero(HeroProfile profile) async => _heroes[profile.id] = jsonDecode(jsonEncode(profile.toJson())) as Map<String, Object?>;

  @override
  Future<void> deleteHero(String id) async => _heroes.remove(id);

  @override
  Future<Map<String, Object?>> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(Map<String, Object?> settings) async => _settings = settings;
}
