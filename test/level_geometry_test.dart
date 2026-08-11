import 'dart:ui' show Rect;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/levels/level_loader.dart';
import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/game/world/constants.dart';
import 'package:shadow_hunters/game/world/obstacle.dart';
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

  group('Level 12-14 geometry loads', () {
    test('Level 12 loads one obstacle', () async {
      final level = await LevelLoader.load('assets/levels/level_12.json');
      expect(level, isNotNull);
      expect(level!.obstacles.length, 1);
    });

    test('Level 13 loads two obstacles', () async {
      final level = await LevelLoader.load('assets/levels/level_13.json');
      expect(level, isNotNull);
      expect(level!.obstacles.length, 2);
    });

    test('Level 14 loads two obstacles', () async {
      final level = await LevelLoader.load('assets/levels/level_14.json');
      expect(level, isNotNull);
      expect(level!.obstacles.length, 2);
    });
  });

  group('Obstacles stay inside the battlefield', () {
    test('Levels 12-14 obstacles are inside world bounds and on the ground',
        () async {
      for (var lvl = 12; lvl <= 14; lvl++) {
        final level = await LevelLoader.load('assets/levels/level_$lvl.json');
        expect(level, isNotNull, reason: 'level $lvl must load');
        for (final o in level!.obstacles) {
          expect(o.left, greaterThanOrEqualTo(wallThickness));
          expect(o.right, lessThanOrEqualTo(worldWidth - wallThickness));
          expect(o.top, greaterThanOrEqualTo(wallThickness));
          // Obstacle bottom should sit on/above the ground line.
          expect(o.bottom, lessThanOrEqualTo(groundY + 1));
          expect(o.width, greaterThan(0));
          expect(o.height, greaterThan(0));
        }
      }
    });

    test('Obstacles do not overlap the player spawn or enemy spawns', () async {
      for (var lvl = 12; lvl <= 14; lvl++) {
        final level = await LevelLoader.load('assets/levels/level_$lvl.json');
        expect(level, isNotNull);
        final points = <Rect>[
          Rect.fromCircle(center: level!.playerSpawn.toOffset(), radius: 20),
        ];
        for (final s in level.enemySpawns) {
          points.add(Rect.fromCircle(center: s.toOffset(), radius: 20));
        }
        for (final o in level.obstacles) {
          for (final p in points) {
            expect(o.overlaps(p), isFalse,
                reason: 'level $lvl obstacle overlaps a spawn point');
          }
        }
      }
    });
  });

  group('Levels 1-11 remain valid (no geometry required)', () {
    test('Levels 1-11 load with valid data and empty obstacles', () async {
      for (var lvl = 1; lvl <= 11; lvl++) {
        final level = await LevelLoader.load('assets/levels/level_$lvl.json');
        expect(level, isNotNull, reason: 'level $lvl must remain valid');
        expect(level!.obstacles, isEmpty,
            reason: 'levels 1-11 should have no obstacles');
      }
    });
  });

  group('Hunter collision', () {
    test('Hunter cannot walk through a solid obstacle', () {
      // Obstacle at x 400..430 on the ground.
      final obstacle = Rect.fromLTWH(400, groundY - 120, 30, 120);
      final hunter = Hunter(
        position: Vector2(360, groundY),
        aim: AimState(),
        obstacles: [obstacle],
      );

      // Walk right toward the obstacle for many frames.
      hunter.moveDirection = 1;
      for (var i = 0; i < 300; i++) {
        hunter.update(1 / 60);
      }
      // The hunter's right edge should not enter the obstacle's left edge.
      expect(hunter.position.x + hunter.size.x / 2,
          lessThanOrEqualTo(obstacle.left + 1));

      // Walk left away from it freely.
      hunter.moveDirection = -1;
      for (var i = 0; i < 300; i++) {
        hunter.update(1 / 60);
      }
      expect(hunter.position.x, lessThan(360));
    });
  });

  group('Arrow obstacle collision', () {
    test('Obstacle.segmentIntersectsRect detects a crossing segment', () {
      final rect = Rect.fromLTWH(100, 100, 40, 40);
      // Segment clearly crossing the rect.
      expect(
        Obstacle.segmentIntersectsRect(
          Vector2(50, 120),
          Vector2(200, 120),
          rect,
        ),
        isTrue,
      );
      // Segment clearly missing the rect.
      expect(
        Obstacle.segmentIntersectsRect(
          Vector2(50, 10),
          Vector2(200, 10),
          rect,
        ),
        isFalse,
      );
      // Segment ending inside the rect.
      expect(
        Obstacle.segmentIntersectsRect(
          Vector2(50, 120),
          Vector2(120, 120),
          rect,
        ),
        isTrue,
      );
    });

    testWidgets('The game loads Level 12 geometry and the collision function '
        'works on the real obstacle rect', (tester) async {
      final game = await makeGame(tester, 12);
      addTearDown(game.dispose);

      final obs = game.levelData.obstacles.single;
      expect(obs.left, greaterThan(1000));

      // A flight segment that crosses the obstacle's x-range at a y inside it
      // must be flagged as a hit (this is the same function the game uses to
      // stop arrows, so it cannot pass through the obstacle).
      final centerY = obs.center.dy;
      expect(
        Obstacle.segmentIntersectsRect(
          Vector2(obs.left - 200, centerY),
          Vector2(obs.right + 200, centerY),
          obs,
        ),
        isTrue,
      );
      // A segment well above the obstacle is not a hit.
      expect(
        Obstacle.segmentIntersectsRect(
          Vector2(obs.left - 200, obs.top - 50),
          Vector2(obs.right + 200, obs.top - 50),
          obs,
        ),
        isFalse,
      );
    });
  });
}
