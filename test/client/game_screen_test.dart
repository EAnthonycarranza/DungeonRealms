import 'package:dungeon_realms/client/game_screen.dart';
import 'package:dungeon_realms/content/game_data.dart';
import 'package:dungeon_realms/game/dungeon_realms_game.dart';
import 'package:dungeon_realms/rules/hero_profile.dart';
import 'package:dungeon_realms/rules/items.dart';
import 'package:dungeon_realms/services/save_repository.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone behaviors of the game screen: the app going to the background and
/// the Android back button.
///
/// Everything runs against one booted game: loading the real map twice in one
/// widget-test file stalls in flame_tiled's async atlas building.
void main() {
  testWidgets('leaving the app pauses and saves; Android back toggles the pause menu', (tester) async {
    late GameData data;
    late HeroProfile profile;
    final saves = MemorySaveRepository();
    await tester.runAsync(() async {
      data = await GameData.load();
      profile = HeroProfile.create(data, 'ranger', 'leafwarden', ItemFactory(data));
    });
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(data: data, profile: profile, saves: saves),
      ),
    );

    // Loading decodes the real map and sprite sheets, which needs real time.
    final game = tester.widget<GameWidget<DungeonRealmsGame>>(find.byType(GameWidget<DungeonRealmsGame>)).game!;
    for (var i = 0; i < 300 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isLoaded, isTrue, reason: 'the game should finish loading');

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The home button (or a call): the pause menu opens and the hero is saved.
    expect(find.text('Paused'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle();
    expect(find.text('Paused'), findsOneWidget);
    expect(game.paused, isTrue);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(await tester.runAsync(() => saves.loadHero(profile.id)), isNotNull);

    // Coming back keeps the game paused behind the menu.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle();
    expect(find.text('Paused'), findsOneWidget);
    expect(game.paused, isTrue);

    // Android back closes the menu, and a second back opens it again instead
    // of quitting the app.
    Future<void> back() async {
      expect(await tester.binding.handlePopRoute(), isTrue, reason: 'the game screen must handle back');
      await settle();
    }

    await back();
    expect(find.text('Paused'), findsNothing);
    expect(game.paused, isFalse);
    await back();
    expect(find.text('Paused'), findsOneWidget);
  });
}
