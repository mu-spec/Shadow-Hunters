import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/game/world/constants.dart' show skeletonMaxHealth;
import 'package:shadow_hunters/services/settings_service.dart';

import 'helpers/asset_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Loads the REAL Level 5 game (multi-enemy "First Battle") laid out in a
  // GameWidget, exactly as the runtime does, then applies a landscape size.
  Future<ShadowHuntersGame> makeLevel5(WidgetTester tester) async {
    mockLevelAssets(tester);

    final settings = SettingsService();
    await settings.load();
    final game = ShadowHuntersGame(settings: settings, levelNumber: 5);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
    });
    await tester.pump();
    game.onGameResize(Vector2(800, 360));
    return game;
  }

  testWidgets('Level 5 spawns 3 Skeletons at separate positions',
      (tester) async {
    final game = await makeLevel5(tester);
    addTearDown(game.dispose);

    // HUD starts with Enemies: 3.
    expect(game.totalEnemies, 3);
    expect(game.liveEnemies, 3);

    // All 3 are independently active entities.
    final xs = game.skeletons.map((s) => s.position.x).toSet();
    expect(xs.length, 3, reason: 'Skeletons must spawn at 3 separate positions');
    expect(game.skeletons.every((s) => !s.isDead), isTrue);
  });

  testWidgets('Victory does NOT trigger after only one Skeleton dies',
      (tester) async {
    final game = await makeLevel5(tester);
    addTearDown(game.dispose);

    // Kill just the first Skeleton.
    game.skeletons[0].takeDamage(skeletonMaxHealth);
    game.update(1 / 60);

    expect(game.skeletons[0].isDead, isTrue);
    expect(game.liveEnemies, 2, reason: 'Two Skeletons should remain alive');
    expect(game.statusNotifier.value, isNot(GameStatus.victory),
        reason: 'Victory must NOT fire while 2 enemies are still alive');
  });

  testWidgets('Victory fires only after ALL 3 Skeletons are dead',
      (tester) async {
    final game = await makeLevel5(tester);
    addTearDown(game.dispose);

    for (final skeleton in game.skeletons) {
      skeleton.takeDamage(skeletonMaxHealth);
    }
    game.update(1 / 60);

    expect(game.liveEnemies, 0);
    expect(game.statusNotifier.value, GameStatus.victory);
  });

  testWidgets('Restart restores all 3 Skeletons for Level 5', (tester) async {
    final game = await makeLevel5(tester);
    addTearDown(game.dispose);

    // Kill one enemy, then restart — all 3 must come back.
    game.skeletons[0].takeDamage(skeletonMaxHealth);
    game.update(1 / 60);
    expect(game.liveEnemies, 2);

    await game.restart();

    expect(game.totalEnemies, 3, reason: 'Restart must restore all 3 enemies');
    expect(game.liveEnemies, 3);
    expect(game.skeletons.every((s) => !s.isDead), isTrue);
    expect(game.statusNotifier.value, isNot(GameStatus.victory));
  });
}
