import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/game/world/constants.dart';
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

  group('Boss projectile collision (Phase 7 fix V2)', () {
    // Kills the boss so it can't fire its own projectiles and interfere with
    // exact single-hit damage assertions.
    void silenceBoss(ShadowHuntersGame game) {
      game.boss?.takeDamage(bossMaxHealth);
      game.update(1 / 60);
    }

    testWidgets('direct projectile hit decreases Hunter health',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final healthBefore = game.hunter.health;
      final hunterCenter =
          game.hunter.position + Vector2(0, -game.hunter.size.y / 2);
      await game.fireBossRanged(hunterCenter - Vector2(60, 0), Vector2(1, 0));
      // Run enough frames for the projectile (speed 260) to reach the Hunter.
      for (var i = 0; i < 200; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }
      await tester.pump();

      expect(game.hunter.health, lessThan(healthBefore),
          reason: 'Hunter should take ranged damage on a direct hit');
    });

    testWidgets(
        'REAL movement: projectile crosses the Hunter in a single frame '
        '(swept) and hits once', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final healthBefore = game.hunter.health;
      // Aim straight at the Hunter's body vertical centre.
      final hunterTop = game.hunter.collisionRect.top;
      final hunterBottom = game.hunter.collisionRect.bottom;
      final bodyY = (hunterTop + hunterBottom) / 2;
      // Start just left of the Hunter's collision rect.
      final fromX = game.hunter.collisionRect.left - 40;
      await game.fireBossRanged(Vector2(fromX, bodyY), Vector2(1, 0));

      // A single large-dt step moves the projectile from one side of the Hunter
      // to the other in ONE frame. Swept collision must still catch it.
      game.update(0.5);
      await tester.pump();

      expect(game.hunter.health, healthBefore - bossRangedDamage.toInt(),
          reason: 'swept path must intersect Hunter and deal exactly one hit');
      expect(game.bossProjectiles, isEmpty,
          reason: 'projectile must be removed after the swept hit');
    });

    testWidgets('high-speed projectile crossing between frames still hits once',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final healthBefore = game.hunter.health;
      final bodyY =
          (game.hunter.collisionRect.top + game.hunter.collisionRect.bottom) /
              2;
      final fromX = game.hunter.collisionRect.left - 30;
      await game.fireBossRanged(Vector2(fromX, bodyY), Vector2(1, 0));

      // Very large step so the projectile completely skips over the Hunter's
      // position between frames — swept test must prevent tunneling.
      game.update(0.9);
      game.update(0.9);
      await tester.pump();

      expect(game.hunter.health, healthBefore - bossRangedDamage.toInt(),
          reason: 'high-speed projectile must not tunnel through the Hunter');
      expect(game.bossProjectiles, isEmpty,
          reason: 'projectile removed after the high-speed hit');
    });

    testWidgets('near miss does NOT damage the Hunter', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final healthBefore = game.hunter.health;
      // Aim well ABOVE the Hunter's collision rect so it flies over.
      final aboveY = game.hunter.collisionRect.top - 80;
      final fromX = game.hunter.collisionRect.left - 60;
      await game.fireBossRanged(Vector2(fromX, aboveY), Vector2(1, 0));
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }
      await tester.pump();

      expect(game.hunter.health, healthBefore,
          reason: 'near miss must not damage the Hunter');
    });

    testWidgets('paused projectile does not damage or move', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final healthBefore = game.hunter.health;
      final bodyY =
          (game.hunter.collisionRect.top + game.hunter.collisionRect.bottom) /
              2;
      final fromX = game.hunter.collisionRect.left - 60;
      await game.fireBossRanged(Vector2(fromX, bodyY), Vector2(1, 0));
      final posBefore = game.bossProjectiles.single.position.clone();

      // In the real game, the engine loop does NOT call update() while paused,
      // so the projectile cannot move or deal damage. Pausing must leave it
      // exactly where it was (no movement, no damage) until the game resumes.
      game.pauseGame();
      expect(game.paused, isTrue);
      expect(game.bossProjectiles, isNotEmpty);
      expect(game.bossProjectiles.single.position.distanceTo(posBefore),
          lessThan(0.001),
          reason: 'paused projectile must not move');
      expect(game.hunter.health, healthBefore,
          reason: 'paused projectile must not damage the Hunter');

      // Resume: the projectile is still active and free to continue.
      game.resumeGame();
      expect(game.paused, isFalse);
      expect(game.bossProjectiles, isNotEmpty);
    });

    testWidgets('one projectile cannot damage the Hunter twice',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final bodyY =
          (game.hunter.collisionRect.top + game.hunter.collisionRect.bottom) /
              2;
      final fromX = game.hunter.collisionRect.left - 40;
      await game.fireBossRanged(Vector2(fromX, bodyY), Vector2(1, 0));
      // Run many frames after the hit; damage must occur exactly once.
      for (var i = 0; i < 400; i++) {
        game.update(1 / 60);
      }
      await tester.pump();
      final damage = 100 - game.hunter.health;
      expect(damage, bossRangedDamage.toInt(),
          reason: 'Hunter should lose exactly one ranged attack worth of HP');
    });

    testWidgets('projectile outside world bounds is removed', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      // Fire upward/right from a position that leaves the world quickly.
      await game.fireBossRanged(Vector2(200, 400), Vector2(1, 0));
      for (var i = 0; i < 600; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }
      await tester.pump();
      expect(game.bossProjectiles, isEmpty,
          reason: 'projectile must be removed when it leaves world bounds');
    });

    testWidgets('restart clears old boss projectiles', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();
      silenceBoss(game);

      final bodyY =
          (game.hunter.collisionRect.top + game.hunter.collisionRect.bottom) /
              2;
      await game.fireBossRanged(
          Vector2(game.hunter.collisionRect.left - 50, bodyY), Vector2(1, 0));
      expect(game.bossProjectiles, isNotEmpty);

      // Restart (which re-shows the boss intro) must clear projectiles.
      await game.restart();
      expect(game.bossProjectiles, isEmpty,
          reason: 'restart must remove old boss projectiles');
    });
  });
}
