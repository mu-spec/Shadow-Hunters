import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/entities/skeleton.dart';
import 'package:shadow_hunters/game/entities/zombie.dart';
import 'package:shadow_hunters/game/levels/level_loader.dart';
import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/services/settings_service.dart';

import 'helpers/asset_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ShadowHuntersGame> makeGame(WidgetTester tester, int level) async {
    mockLevelAssets(tester);
    final settings = SettingsService();
    await settings.load();
    final game = ShadowHuntersGame(settings: settings, levelNumber: level);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
    });
    await tester.pump();
    game.onGameResize(Vector2(800, 360));
    return game;
  }

  testWidgets('Level 6 contains exactly one Zombie', (tester) async {
    final game = await makeGame(tester, 6);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 1);
    expect(game.enemies.single, isA<Zombie>());
    expect(game.liveEnemies, 1);
  });

  testWidgets('Level 7 contains one Skeleton and one Zombie', (tester) async {
    final game = await makeGame(tester, 7);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 2);
    expect(game.enemies.whereType<Skeleton>().length, 1);
    expect(game.enemies.whereType<Zombie>().length, 1);
    expect(game.liveEnemies, 2);
  });

  testWidgets('Level 8 contains two Zombies at separate positions',
      (tester) async {
    final game = await makeGame(tester, 8);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 2);
    expect(game.enemies.whereType<Zombie>().length, 2);
    final xs = game.enemies.map((e) => e.position.x).toSet();
    expect(xs.length, 2, reason: 'Two Zombies must start at different positions');
    expect(game.liveEnemies, 2);
  });

  testWidgets('Level 6 victory requires the Zombie to die', (tester) async {
    final game = await makeGame(tester, 6);
    addTearDown(game.dispose);

    // Kill the single Zombie.
    game.enemies[0].takeDamage(10000);
    game.update(1 / 60);
    expect(game.liveEnemies, 0);
    expect(game.statusNotifier.value, GameStatus.victory);
  });

  test('Level 7 JSON declares per-spawn mixed enemy types', () async {
    final level = await LevelLoader.load('assets/levels/level_7.json');
    expect(level, isNotNull);
    expect(level!.enemyCount, 2);
    expect(level.enemySpawnTypes, ['skeleton', 'zombie']);
    expect(level.enemyTypeFor(0), 'skeleton');
    expect(level.enemyTypeFor(1), 'zombie');
  });
}
