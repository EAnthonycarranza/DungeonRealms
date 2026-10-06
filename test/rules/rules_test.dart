import 'dart:convert';
import 'dart:math' as math;

import 'package:dungeon_realms/content/game_data.dart';
import 'package:dungeon_realms/rules/hero_profile.dart';
import 'package:dungeon_realms/rules/inventory.dart';
import 'package:dungeon_realms/rules/items.dart';
import 'package:dungeon_realms/rules/loot.dart';
import 'package:dungeon_realms/rules/quest_log.dart';
import 'package:dungeon_realms/rules/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../content/game_data_test.dart' show loadGameDataFromDisk;

void main() {
  late GameData data;
  late ItemFactory items;

  setUpAll(() => data = loadGameDataFromDisk());
  setUp(() => items = ItemFactory(data, math.Random(7)));

  group('items', () {
    test('rolled items respect rarity affix counts and slots', () {
      for (final rarity in ['common', 'uncommon', 'rare', 'epic']) {
        final item = items.roll(level: 5, heroClass: 'ranger', rarity: rarity);
        expect(item.rarity, rarity);
        expect(item.affixIds.length, data.rarity(rarity).affixes);
        final slot = data.bases[item.baseId]!.slot;
        for (final a in item.affixIds) {
          expect(data.affixes.firstWhere((x) => x.id == a).slots, contains(slot));
        }
      }
    });

    test('legendaries keep their fixed name and power', () {
      final bow = items.legendary('stormwood_bow', 6);
      expect(bow.name, 'Stormwood Bow');
      expect(bow.isLegendary, isTrue);
      expect(bow.stats['attack'], greaterThan(30));
      expect(data.legendaries[bow.legendaryId]!.power.id, 'stormcaller');
    });

    test('item JSON round-trips', () {
      final item = items.roll(level: 3, heroClass: 'ranger', rarity: 'rare');
      final copy = ItemInstance.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>);
      expect(copy.name, item.name);
      expect(copy.stats, item.stats);
      expect(copy.affixIds, item.affixIds);
    });

    test('rarity weights favour common drops', () {
      final counts = <String, int>{};
      for (var i = 0; i < 4000; i++) {
        final r = items.rollRarity();
        counts[r] = (counts[r] ?? 0) + 1;
      }
      expect(counts['common']!, greaterThan(counts['rare']!));
      expect(counts['rare']!, greaterThan(counts['legendary'] ?? 0));
    });
  });

  group('inventory & stats', () {
    test('equipping swaps with the bag and changes stats', () {
      final hero = data.heroes['ranger']!;
      final inv = Inventory();
      final weak = items.roll(level: 1, heroClass: 'ranger', rarity: 'common', baseId: 'short_bow');
      final strong = items.legendary('stormwood_bow', 6);
      inv.addItem(weak);
      inv.equip(weak, data);
      inv.addItem(strong);
      final before = HeroStats.compute(hero, 5, inv.equipped.values);
      inv.equip(strong, data);
      final after = HeroStats.compute(hero, 5, inv.equipped.values);
      expect(inv.equipped['weapon']!.uid, strong.uid);
      expect(inv.bag.single.uid, weak.uid);
      expect(after.attack, greaterThan(before.attack));
      expect(after.critChance, greaterThan(before.critChance));
    });

    test('salvage converts items into shiny bits', () {
      final inv = Inventory();
      final item = items.roll(level: 2, heroClass: 'ranger', rarity: 'rare');
      inv.addItem(item);
      expect(inv.salvage(item, data), data.rarity('rare').salvage);
      expect(inv.bag, isEmpty);
    });

    test('armor mitigation is between 0 and 1 and weakens vs higher levels', () {
      final m = DamageMath(data.progression);
      expect(m.mitigation(0, 1), 1);
      expect(m.mitigation(50, 1), lessThan(1));
      expect(m.mitigation(50, 10), greaterThan(m.mitigation(50, 1)));
      expect(m.xpToNext(2), greaterThan(m.xpToNext(1)));
    });
  });

  group('quests', () {
    test('kill objectives count goblins by tag and become ready', () {
      final log = QuestLog(data);
      final inv = Inventory();
      expect(log.status('goblins_in_my_woods'), QuestStatus.available);
      expect(log.status('camp_crasher'), QuestStatus.locked);
      log.accept('goblins_in_my_woods', inv);
      for (var i = 0; i < 6; i++) {
        log.onKill(data.enemies['goblin_grunt']!);
      }
      expect(log.status('goblins_in_my_woods'), QuestStatus.ready);
      log.complete('goblins_in_my_woods');
      expect(log.status('camp_crasher'), QuestStatus.available);
    });

    test('collect objectives follow inventory counts', () {
      final log = QuestLog(data);
      final inv = Inventory()..addMaterial('copper_ore', 2);
      log.accept('rock_and_stone', inv);
      expect(log.state('rock_and_stone').counts.first, 2);
      inv.addMaterial('copper_ore', 3);
      log.onMaterials(inv);
      expect(log.status('rock_and_stone'), QuestStatus.ready);
    });

    test('npc focus prefers turn-ins', () {
      final log = QuestLog(data);
      expect(log.focusFor('captain_bramble')!.id, 'goblins_in_my_woods');
      expect(log.hasSomethingFor('pip_puddlefoot'), isTrue);
    });
  });

  group('profile & loot', () {
    test('new heroes start with equipped gear and survive a save round-trip', () {
      final profile = HeroProfile.create(data, 'ranger', 'leafwarden', items);
      expect(profile.inventory.equipped['weapon'], isNotNull);
      profile.bossKills.add('normal:grizzlefang');
      final copy = HeroProfile.fromJson(jsonDecode(jsonEncode(profile.toJson())) as Map<String, Object?>);
      expect(copy.inventory.equipped.keys, profile.inventory.equipped.keys);
      expect(copy.unlockedDifficulties(data).map((d) => d.id), contains('spicy'));
    });

    test('boss loot always contains a legendary', () {
      final roller = LootRoller(data, items, math.Random(3));
      final drops = roller.roll('boss_grizzlefang', level: 8, heroClass: 'ranger');
      expect(drops.any((d) => d.kind == DropKind.item && d.item!.isLegendary), isTrue);
      expect(drops.any((d) => d.kind == DropKind.gold), isTrue);
    });
  });
}
