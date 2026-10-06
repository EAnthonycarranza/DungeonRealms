import 'dart:convert';
import 'dart:io';

import 'package:dungeon_realms/content/game_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads game data straight from disk (no asset bundle needed).
GameData loadGameDataFromDisk() {
  Map<String, Object?> read(String path) => (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();
  final files = {for (final f in GameData.files) f: read('game_data/$f')};
  final sprites = {for (final id in GameData.spriteIdsIn(files)) id: read('assets/images/sprites/$id.json')};
  return GameData.fromJson(files, sprites);
}

void main() {
  late GameData data;

  setUpAll(() => data = loadGameDataFromDisk());

  test('all content cross-references resolve', () {
    final problems = data.validate();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the vision roster is present and the Ranger is playable', () {
    expect(data.heroes.keys, containsAll(['ranger', 'monk', 'druid', 'paladin', 'chronomancer', 'sorceress', 'barbarian', 'rogue']));
    expect(data.heroes['ranger']!.playable, isTrue);
    expect(data.heroes['ranger']!.looks.length, 2);
  });

  test('Goblinwood is the playable region with four waypoints', () {
    final region = data.region('goblinwood');
    expect(region.playable, isTrue);
    expect(region.waypoints.map((w) => w.id), contains('buckleburg_gate'));
    expect(region.waypoints.length, 4);
  });

  test('rarity weights are positive and ordered common -> legendary', () {
    expect(data.rarities.first.id, 'common');
    expect(data.rarities.last.id, 'legendary');
    for (final r in data.rarities) {
      expect(r.weight, greaterThan(0));
    }
  });

  test('enemy scaling grows with level', () {
    final s = data.enemyScaling;
    expect(s.hp(100, 5), greaterThan(s.hp(100, 1)));
    expect(s.attack(10, 8), greaterThan(10));
  });

  test('sprite sheets list frames inside their texture', () {
    for (final sheet in data.sprites.values) {
      final file = File('assets/images/sprites/${sheet.image}');
      expect(file.existsSync(), isTrue, reason: sheet.image);
      var maxFrame = 0;
      for (final anim in sheet.animations.values) {
        for (final (start, count) in anim.facings.values) {
          if (start + count > maxFrame) maxFrame = start + count;
        }
      }
      // Sheets are at most 4096 px in each dimension (mobile web limit).
      expect(sheet.columns * sheet.frameWidth, lessThanOrEqualTo(4096), reason: sheet.id);
      final rows = (maxFrame / sheet.columns).ceil();
      expect(rows * sheet.frameHeight, lessThanOrEqualTo(4096), reason: sheet.id);
    }
  });
}
