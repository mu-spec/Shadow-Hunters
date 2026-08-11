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

  testWidgets('Level 12 has 2 Skeletons and 1 Zombie at separate spots',
      (tester) async {
    final game = await makeGame(tester, 12);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 3);
    expect(game.enemies.whereType<Skeleton>().length, 2);
    expect(game.enemies.whereType<Zombie>().length, 1);
    final xs = game.enemies.map((e) => e.position.x).toSet();
    expect(xs.length, 3, reason: 'enemies must spawn at distinct positions');
    expect(game.liveEnemies, 3);
  });

  testWidgets('Level 13 has Skeleton + Zombie + Goblin', (tester) async {
    final game = await makeGame(tester, 13);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 3);
    expect(game.enemies.whereType<Skeleton>().length, 1);
    expect(game.enemies.whereType<Zombie>().length, 1);
    expect(game.enemies.whereType<Goblin>().length, 1);
    expect(game.liveEnemies, 3);
  });

  testWidgets('Level 14 mixes all three enemies', (tester) async {
    final game = await makeGame(tester, 14);
    addTearDown(game.dispose);

    expect(game.totalEnemies, 4);
    expect(game.enemies.whereType<Skeleton>().length, 2);
    expect(game.enemies.whereType<Zombie>().length, 1);
    expect(game.enemies.whereType<Goblin>().length, 1);
    expect(game.liveEnemies, 4);
  });

  testWidgets('Level 14 victory requires killing every enemy', (tester) async {
    final game = await makeGame(tester, 14);
    addTearDown(game.dispose);

    // Kill all but one — no victory yet.
    for (var i = 0; i < game.enemies.length - 1; i++) {
      game.enemies[i].takeDamage(100000);
    }
    game.update(1 / 60);
    expect(game.liveEnemies, 1);
    expect(game.statusNotifier.value, isNot(GameStatus.victory));

    // Kill the last one — victory.
    game.enemies.last.takeDamage(100000);
    game.update(1 / 60);
    expect(game.liveEnemies, 0);
    expect(game.statusNotifier.value, GameStatus.victory);
  });

  test('Level 13 JSON declares per-spawn mixed enemy types', () async {
    final level = await LevelLoader.load('assets/levels/level_13.json');
    expect(level, isNotNull);
    expect(level!.enemyCount, 3);
    expect(level.enemySpawnTypes, ['skeleton', 'zombie', 'goblin']);
  });
}
