import 'dart:ui' show Rect;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/enemy.dart';
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

  // A solid obstacle standing on the ground between an enemy and the Hunter.
  final obstacle = Rect.fromLTWH(600, groundY - 120, 40, 120);

  Hunter makeHunterAt(double x) =>
      Hunter(position: Vector2(x, groundY), aim: AimState());

  /// Runs [enemy] chasing for [frames] frames, asserting the enemy never
  /// intersects [obstacle], and returns the final feet x.
  double runAndTrackX(Enemy enemy, int frames) {
    var lastX = enemy.position.x;
    for (var i = 0; i < frames; i++) {
      enemy.update(1 / 60);
      final body = Rect.fromLTWH(
        enemy.position.x - enemy.size.x / 2,
        enemy.position.y - enemy.size.y,
        enemy.size.x,
        enemy.size.y,
      );
      expect(body.overlaps(obstacle), isFalse,
          reason: 'enemy must never intersect the obstacle while avoiding');
      lastX = enemy.position.x;
    }
    return lastX;
  }

  group('Enemies get around obstacles (deterministic avoidance)', () {
    test('Skeleton encounters an obstacle and eventually gets around it', () {
      final hunter = makeHunterAt(1000); // Hunter is right of the obstacle
      final skeleton =
          Skeleton(position: Vector2(200, groundY), hunter: hunter, obstacles: [obstacle]);
      final finalX = runAndTrackX(skeleton, 4000);
      expect(finalX, greaterThan(obstacle.right),
          reason: 'Skeleton should end up on the Hunter side of the obstacle');
    });

    test('Zombie encounters an obstacle and eventually gets around it', () {
      final hunter = makeHunterAt(1000);
      final zombie =
          Zombie(position: Vector2(200, groundY), hunter: hunter, obstacles: [obstacle]);
      final finalX = runAndTrackX(zombie, 4000);
      expect(finalX, greaterThan(obstacle.right),
          reason: 'Zombie should end up on the Hunter side of the obstacle');
    });

    test('Goblin encounters an obstacle and eventually gets around it', () {
      final hunter = makeHunterAt(1000);
      final goblin =
          Goblin(position: Vector2(200, groundY), hunter: hunter, obstacles: [obstacle]);
      final finalX = runAndTrackX(goblin, 4000);
      expect(finalX, greaterThan(obstacle.right),
          reason: 'Goblin should end up on the Hunter side of the obstacle');
    });

    test('Enemy does not remain permanently stuck (keeps moving)', () {
      final hunter = makeHunterAt(1000);
      final skeleton =
          Skeleton(position: Vector2(200, groundY), hunter: hunter, obstacles: [obstacle]);
      // After running enough frames it must have advanced well past the
      // obstacle, i.e. not be parked at its left edge forever.
      final finalX = runAndTrackX(skeleton, 4000);
      expect(finalX, greaterThan(obstacle.right + 20));
    });
  });

  group('Goblin dodge stays obstacle-safe', () {
    test('Goblin dodge cannot pass through an obstacle', () {
      // Put the hunter to the LEFT of the goblin so the goblin's dodge (which
      // moves away from the Hunter) pushes it to the RIGHT — into the obstacle.
      final hunter = Hunter(position: Vector2(200, groundY), aim: AimState());
      final goblin =
          Goblin(position: Vector2(obstacle.left - 20, groundY), hunter: hunter, obstacles: [obstacle]);

      for (var i = 0; i < 6000; i++) {
        goblin.update(1 / 60);
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

        // Every remaining enemy is alive, within bounds, and never overlaps an
        // obstacle — i.e. none is permanently stuck in a broken state.
        for (final e in game.enemies) {
          if (e.isDead) continue;
          expect(e.position.x.isFinite, isTrue);
          expect(e.position.x, greaterThanOrEqualTo(wallThickness));
          expect(e.position.x, lessThanOrEqualTo(worldWidth - wallThickness));
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
