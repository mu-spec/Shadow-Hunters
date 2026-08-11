import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/entities/goblin.dart';
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

  testWidgets('Level 9 contains exactly one Goblin', (tester) async {
    final game = await makeGame(tester, 9);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 1);
    expect(game.enemies.single, isA<Goblin>());
    expect(game.liveEnemies, 1);
  });

  testWidgets('Level 10 contains one Skeleton and one Goblin', (tester) async {
    final game = await makeGame(tester, 10);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 2);
    expect(game.enemies.whereType<Skeleton>().length, 1);
    expect(game.enemies.whereType<Goblin>().length, 1);
    expect(game.liveEnemies, 2);
  });

  testWidgets('Level 11 contains one Zombie and one Goblin', (tester) async {
    final game = await makeGame(tester, 11);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 2);
    expect(game.enemies.whereType<Zombie>().length, 1);
    expect(game.enemies.whereType<Goblin>().length, 1);
    expect(game.liveEnemies, 2);
  });

  testWidgets('Level 10 victory requires both enemies to die', (tester) async {
    final game = await makeGame(tester, 10);
    addTearDown(game.dispose);

    // Kill only the Skeleton (first enemy) — Goblin must remain, no victory.
    game.enemies[0].takeDamage(10000);
    game.update(1 / 60);
    expect(game.liveEnemies, 1);
    expect(game.statusNotifier.value, isNot(GameStatus.victory));

    // Kill the Goblin too — now victory.
    game.enemies[1].takeDamage(10000);
    game.update(1 / 60);
    expect(game.liveEnemies, 0);
    expect(game.statusNotifier.value, GameStatus.victory);
  });

  test('Level 11 JSON declares per-spawn mixed enemy types', () async {
    final level = await LevelLoader.load('assets/levels/level_11.json');
    expect(level, isNotNull);
    expect(level!.enemyCount, 2);
    expect(level.enemySpawnTypes, ['zombie', 'goblin']);
    expect(level.enemyTypeFor(0), 'zombie');
    expect(level.enemyTypeFor(1), 'goblin');
  });
}
