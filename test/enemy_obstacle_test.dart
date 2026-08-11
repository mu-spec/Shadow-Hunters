import 'dart:ui' show Rect;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/goblin.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/entities/skeleton.dart';
import 'package:shadow_hunters/game/entities/zombie.dart';
import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/game/world/constants.dart';
import 'package:shadow_hunters/services/settings_service.dart';

import 'helpers/asset_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // A solid obstacle standing on the ground between the enemy and the hunter.
  final obstacle = Rect.fromLTWH(600, groundY - 120, 40, 120);

  Hunter makeHunter() =>
      Hunter(position: Vector2(1200, groundY), aim: AimState());

  Skeleton makeSkeleton(Hunter h) =>
      Skeleton(position: Vector2(200, groundY), hunter: h, obstacles: [obstacle]);

  Zombie makeZombie(Hunter h) =>
      Zombie(position: Vector2(200, groundY), hunter: h, obstacles: [obstacle]);

  Goblin makeGoblin(Hunter h) =>
      Goblin(position: Vector2(200, groundY), hunter: h, obstacles: [obstacle]);

  group('Enemies cannot cross solid obstacles', () {
    test('Skeleton cannot cross an obstacle', () {
      final hunter = makeHunter();
      final skeleton = makeSkeleton(hunter);
      // Skeleton is left of the obstacle, hunter is right. Chase right for a
      // long time; it must stop at the obstacle's left edge.
      skeleton.update(1);
      for (var i = 0; i < 3000; i++) {
        skeleton.update(1 / 60);
      }
      // Right edge of skeleton must not pass obstacle's left edge.
      expect(skeleton.position.x + skeleton.size.x / 2,
          lessThanOrEqualTo(obstacle.left + 1));
    });

    test('Zombie cannot cross an obstacle', () {
      final hunter = makeHunter();
      final zombie = makeZombie(hunter);
      for (var i = 0; i < 3000; i++) {
        zombie.update(1 / 60);
      }
      expect(zombie.position.x + zombie.size.x / 2,
          lessThanOrEqualTo(obstacle.left + 1));
    });

    test('Goblin cannot cross an obstacle', () {
      final hunter = makeHunter();
      final goblin = makeGoblin(hunter);
      for (var i = 0; i < 3000; i++) {
        goblin.update(1 / 60);
      }
      expect(goblin.position.x + goblin.size.x / 2,
          lessThanOrEqualTo(obstacle.left + 1));
    });

    test('Goblin dodge cannot pass through an obstacle', () {
      // Put the hunter to the LEFT of the goblin so the goblin's dodge (which
      // moves away from the Hunter) pushes it to the RIGHT — into the obstacle.
      final hunter = Hunter(position: Vector2(200, groundY), aim: AimState());
      final goblin = makeGoblin(hunter);
      // Just left of the obstacle, so a rightward dodge would try to enter it.
      goblin.position.x = obstacle.left - 20;

      // Run many frames including possible dodges; it must never enter the
      // obstacle's interior.
      for (var i = 0; i < 6000; i++) {
        goblin.update(1 / 60);
        // Verify the goblin body never overlaps the obstacle.
        final body = Rect.fromLTWH(
          goblin.position.x - goblin.size.x / 2,
          goblin.position.y - goblin.size.y,
          goblin.size.x,
          goblin.size.y,
        );
        expect(body.overlaps(obstacle), isFalse,
            reason: 'goblin dodge must never carry it through the obstacle');
      }
    });
  });

  group('Enemies do not get permanently stuck in Levels 12-14', () {
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

    for (var lvl = 12; lvl <= 14; lvl++) {
      testWidgets('Level $lvl: enemies stay valid, in bounds, not stuck',
          (tester) async {
        final game = await makeGame(tester, lvl);
        addTearDown(game.dispose);

        expect(game.enemies.length, greaterThanOrEqualTo(1));

        // Simulate many frames of gameplay.
        for (var i = 0; i < 6000; i++) {
          game.update(1 / 60);
        }

        // Every remaining enemy is alive, within bounds, and has a valid
        // (non-NaN) position — i.e. none is permanently stuck in a broken state.
        for (final e in game.enemies) {
          if (e.isDead) continue;
          expect(e.position.x.isFinite, isTrue);
          expect(e.position.x, greaterThanOrEqualTo(wallThickness));
          expect(e.position.x, lessThanOrEqualTo(worldWidth - wallThickness));
          // Never overlapping an obstacle.
          final body = Rect.fromLTWH(
            e.position.x - e.size.x / 2,
            e.position.y - e.size.y,
            e.size.x,
            e.size.y,
          );
          for (final o in game.levelData.obstacles) {
            expect(body.overlaps(o), isFalse,
                reason: 'enemy must not overlap obstacle in level $lvl');
          }
        }
      });
    }
  });
}
