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

  group('Boss projectile collision (Phase 7 fix)', () {
    testWidgets('projectile that intersects the Hunter decreases Hunter health',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      final healthBefore = game.hunter.health;

      // Fire a boss projectile directly at the Hunter's torso.
      final hunterCenter =
          game.hunter.position + Vector2(0, -game.hunter.size.y / 2);
      await game.fireBossRanged(
        hunterCenter - Vector2(200, 0), // to the left, aiming right
        Vector2(1, 0), // straight right into the Hunter
      );
      expect(game.bossProjectiles, isNotEmpty);

      // Run frames so the projectile sweeps into the Hunter.
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }

      expect(game.hunter.health, lessThan(healthBefore),
          reason: 'Hunter should take ranged damage on a valid hit');
    });

    testWidgets('projectile is removed after hitting the Hunter',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      final hunterCenter =
          game.hunter.position + Vector2(0, -game.hunter.size.y / 2);
      await game.fireBossRanged(hunterCenter - Vector2(200, 0), Vector2(1, 0));

      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }

      expect(game.bossProjectiles, isEmpty,
          reason: 'projectile should be removed immediately after a hit');
    });

    testWidgets('one projectile cannot damage the Hunter twice',
        (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      // Remove the boss from the equation so only our manually-fired projectile
      // can deal ranged damage (the boss would otherwise fire its own and break
      // the exact-damage assertion).
      game.boss!.takeDamage(bossMaxHealth);
      game.update(1 / 60);

      final hunterCenter =
          game.hunter.position + Vector2(0, -game.hunter.size.y / 2);
      await game.fireBossRanged(hunterCenter - Vector2(200, 0), Vector2(1, 0));

      // Run enough frames for a hit and several more after; the projectile is
      // consumed on the first hit, so damage must only occur once.
      for (var i = 0; i < 400; i++) {
        game.update(1 / 60);
      }
      final damage = 100 - game.hunter.health;
      expect(damage, bossRangedDamage.toInt(),
          reason: 'Hunter should lose exactly one ranged attack worth of HP');
    });

    testWidgets('projectile outside world bounds is removed', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      // Fire upward/left from a position that leaves the world quickly.
      await game.fireBossRanged(Vector2(200, 400), Vector2(1, 0));
      for (var i = 0; i < 600; i++) {
        game.update(1 / 60);
        if (game.bossProjectiles.isEmpty) break;
      }
      expect(game.bossProjectiles, isEmpty,
          reason: 'projectile must be removed when it leaves world bounds');
    });

    testWidgets('restart clears old boss projectiles', (tester) async {
      final game = await makeGame(tester, 15);
      addTearDown(game.dispose);
      game.dismissBossIntro();

      final hunterCenter =
          game.hunter.position + Vector2(0, -game.hunter.size.y / 2);
      await game.fireBossRanged(hunterCenter - Vector2(50, 0), Vector2(1, 0));
      expect(game.bossProjectiles, isNotEmpty);

      // Restart (which re-shows the boss intro) must clear projectiles.
      await game.restart();
      expect(game.bossProjectiles, isEmpty,
          reason: 'restart must remove old boss projectiles');
    });
  });
}
