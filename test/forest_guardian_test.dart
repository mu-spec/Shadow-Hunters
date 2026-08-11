import 'dart:ui' show Rect;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/app/settings_scope.dart';
import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/enemy.dart';
import 'package:shadow_hunters/game/entities/forest_guardian.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/levels/level_loader.dart';
import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/game/world/constants.dart';
import 'package:shadow_hunters/screens/game_screen.dart';
import 'package:shadow_hunters/services/settings_service.dart';

import 'helpers/asset_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ForestGuardian makeBoss(Hunter h, {List<Rect> obstacles = const []}) =>
      ForestGuardian(position: Vector2(1200, groundY), hunter: h, obstacles: obstacles);

  group('Forest Guardian stats (Milestone 7A)', () {
    test('boss is large, slow, and high health', () {
      final h = Hunter(position: Vector2(220, groundY), aim: AimState());
      final boss = makeBoss(h);
      // Large target (a Zombie, the biggest normal enemy, is 58 wide).
      expect(boss.size.x, greaterThan(58));
      expect(boss.size.y, greaterThan(100));
      // Slow movement.
      expect(bossSpeed, lessThan(skeletonSpeed));
      // High health.
      expect(boss.health, greaterThan(zombieMaxHealth));
    });

    test('strong melee and weak point bonus damage', () {
      final h = Hunter(position: Vector2(220, groundY), aim: AimState());
      final boss = makeBoss(h);
      // Strong melee.
      expect(bossAttackDamage, greaterThan(skeletonAttackDamage));
      // Weak point (head) deals bonus damage over body.
      expect(boss.damageFor(EnemyHitZone.head),
          greaterThan(boss.damageFor(EnemyHitZone.body)));
      // Weak point hit zone is recognized on the head.
      final headY = boss.position.y + bossHeadOffsetY;
      expect(
        boss.hitZoneAlongPath(
          Vector2(boss.position.x - 100, headY),
          Vector2(boss.position.x + 100, headY),
        ),
        EnemyHitZone.head,
      );
    });
  });

  group('Forest Guardian ranged attack', () {
    test('telegraphs then fires a ranged projectile at the Hunter', () {
      final h = Hunter(position: Vector2(2000, groundY), aim: AimState());
      Vector2? firedFrom;
      Vector2? firedDir;
      final boss = ForestGuardian(
        position: Vector2(400, groundY),
        hunter: h,
        onRangedFire: (from, dir) {
          firedFrom = from;
          firedDir = dir;
        },
      );

      // Run long enough for the cooldown to be ready and the warning to finish.
      for (var i = 0; i < 400; i++) {
        boss.update(1 / 60);
      }

      expect(firedDir, isNotNull, reason: 'boss should fire at range');
      expect(firedDir!.x, greaterThan(0), reason: 'fires toward the Hunter');
      expect(firedFrom, isNotNull);
    });

    test('does NOT fire when the Hunter is too close (melee range)', () {
      final h = Hunter(position: Vector2(500, groundY), aim: AimState());
      var fired = false;
      final boss = ForestGuardian(
        position: Vector2(480, groundY),
        hunter: h,
        onRangedFire: (_, __) => fired = true,
      );
      for (var i = 0; i < 400; i++) {
        boss.update(1 / 60);
      }
      expect(fired, isFalse, reason: 'boss uses melee at close range');
    });
  });

  group('Boss level (15) integration', () {
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

    testWidgets('Level 15 loads the boss and shows intro', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);

      expect(game.isBossLevel, isTrue);
      expect(game.boss, isNotNull);
      expect(game.boss, isA<ForestGuardian>());
      expect(game.boss!.health, bossMaxHealth);
      // Intro is shown.
      expect(game.bossIntroVisible.value, isTrue);
      expect(game.bossNameNotifier.value, isNotEmpty);
    });

    testWidgets('Boss health bar reflects boss health', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);

      // Dismiss the intro so the engine unpauses and update() runs.
      game.dismissBossIntro();

      expect(game.bossHealthNotifier.value, closeTo(1.0, 0.001));
      game.boss!.takeDamage(bossMaxHealth ~/ 2);
      game.update(1 / 60);
      expect(game.bossHealthNotifier.value, lessThan(1.0));
      expect(game.bossHealthNotifier.value, greaterThan(0.0));
    });

    testWidgets('Victory triggers only after the boss dies', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      // Damage the boss but not kill it.
      game.boss!.takeDamage(10);
      game.update(1 / 60);
      expect(game.statusNotifier.value, isNot(GameStatus.victory));

      // Kill the boss.
      game.boss!.takeDamage(bossMaxHealth);
      game.update(1 / 60);
      expect(game.liveEnemies, 0);
      expect(game.statusNotifier.value, GameStatus.victory);
    });

    test('Level 15 JSON declares boss name/intro', () async {
      final level = await LevelLoader.load('assets/levels/level_15.json');
      expect(level, isNotNull);
      expect(level!.enemyType, 'forest_guardian');
      expect(level.bossName, 'FOREST GUARDIAN');
      expect(level.bossIntro, isNotEmpty);
      expect(level.enemyCount, 1);
    });

    testWidgets('Level 15 victory shows the V1 completion screen',
        (tester) async {
      // Pump the real GameScreen so the completion overlay can render.
      final settings = SettingsService();
      await settings.load();
      mockLevelAssets(tester);
      await tester.pumpWidget(
        SettingsScope(
          service: settings,
          child: const MaterialApp(home: GameScreen(levelNumber: 15)),
        ),
      );
      await tester.pump();

      // Grab the game created by GameScreen (mounted in its GameWidget).
      final game =
          tester.widget<GameWidget>(find.byType(GameWidget)).game as ShadowHuntersGame;
      addTearDown(game.dispose);

      // Let the real (mocked) asset load finish, then dismiss the intro.
      await tester.runAsync(() => game.toBeLoaded());
      await tester.pump();
      game.dismissBossIntro();
      await tester.pump();

      // Kill the boss -> victory -> completion screen text appears.
      game.boss!.takeDamage(bossMaxHealth);
      game.update(1 / 60);
      await tester.pump();

      expect(game.statusNotifier.value, GameStatus.victory);
      expect(find.text('ENCHANTED FOREST SAVED'), findsOneWidget);
      expect(find.text('V1 COMPLETE'), findsOneWidget);
      expect(find.text('REPLAY LEVELS'), findsOneWidget);
      expect(find.text('MAIN MENU'), findsOneWidget);
    });
  });
}
