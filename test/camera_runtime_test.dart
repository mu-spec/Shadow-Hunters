import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/game/shadow_hunters_game.dart';
import 'package:shadow_hunters/services/settings_service.dart';

import 'helpers/asset_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Loads the real game laid out in a GameWidget (so Flame gives it a size and
  // runs onLoad correctly), then applies a landscape size.
  Future<ShadowHuntersGame> makeGame(WidgetTester tester) async {
    // Mock the flutter/assets platform channel so the game's onLoad() can read
    // the level JSON. In `flutter test` that channel returns null by default
    // (hence "Unable to load asset"), and the error escapes as unhandled async
    // work after the test completes. We serve the real level files from disk.
    mockLevelAssets(tester);

    final settings = SettingsService();
    await settings.load();
    final game = ShadowHuntersGame(settings: settings);
    // onLoad() awaits the (now mocked) asset load. runAsync runs the real event
    // loop so the File I/O + toBeLoaded() future actually complete; otherwise
    // the async load never finishes on testWidgets' fake clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
    });
    await tester.pump();
    game.onGameResize(Vector2(800, 360));
    return game;
  }

  testWidgets(
      'R11 integration: camera follows Hunter right and comes back left',
      (tester) async {
    final game = await makeGame(tester);
    addTearDown(game.dispose);

    // Camera starts at world origin (left boundary).
    expect(game.camera.viewfinder.position.x, 0);

    // Move the Hunter well to the right (past the 35% follow point) by driving
    // his position directly, then run many update frames so the camera follows.
    game.hunter.position.x = 1500;
    for (var i = 0; i < 300; i++) {
      game.update(1 / 60);
    }

    // The camera must have followed right (position.x > 0).
    final camRight = game.camera.viewfinder.position.x;
    expect(camRight, greaterThan(0));

    // The Hunter must remain inside the visible horizontal viewport.
    // visible world width = size.x / zoom.
    final zoom = game.camera.viewfinder.zoom;
    final visibleW = game.size.x / zoom;
    final hunterScreenX = game.hunter.position.x - camRight;
    expect(hunterScreenX, greaterThanOrEqualTo(0));
    expect(hunterScreenX, lessThanOrEqualTo(visibleW));

    // Move the Hunter back left and run updates again.
    game.hunter.position.x = 200;
    for (var i = 0; i < 300; i++) {
      game.update(1 / 60);
    }
    // Camera should come back toward (or to) the left boundary.
    final camLeft = game.camera.viewfinder.position.x;
    expect(camLeft, lessThan(camRight));
  });

  testWidgets('R11 integration: camera never goes below 0 (left boundary)',
      (tester) async {
    final game = await makeGame(tester);
    addTearDown(game.dispose);

    // Hunter at the far left; run updates. Camera must not go below 0.
    game.hunter.position.x = 0;
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(game.camera.viewfinder.position.x, greaterThanOrEqualTo(0));
  });

  group('R12 pause/resume', () {
    testWidgets('pause freezes the simulation; resume restores it',
        (tester) async {
      final game = await makeGame(tester);
      addTearDown(game.dispose);

      // Place the Hunter somewhere and run updates (not paused) — nothing
      // should be overwritten/jump.
      game.hunter.position.x = 300;
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }
      final beforePause = game.hunter.position.x;

      // Pause the engine. update() becomes a no-op: the Hunter must stay frozen.
      game.pauseGame();
      expect(game.pauseNotifier.value, isTrue);
      expect(game.paused, isTrue);
      for (var i = 0; i < 200; i++) {
        game.update(1 / 60); // no-op while paused
      }
      expect(game.hunter.position.x, closeTo(beforePause, 0.001));

      // Resume. The engine returns to normal (no dt jump), hunter stays put.
      game.resumeGame();
      expect(game.pauseNotifier.value, isFalse);
      expect(game.paused, isFalse);
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }
      expect(game.hunter.position.x, closeTo(beforePause, 0.001));
    });

    testWidgets('no firing while paused (aim is dropped on pause)',
        (tester) async {
      final game = await makeGame(tester);
      addTearDown(game.dispose);

      game.aim.active = true;
      game.pauseGame();
      // pauseGame drops aim.active, so a fire can't be triggered while paused.
      expect(game.aim.active, isFalse);
      expect(game.pauseNotifier.value, isTrue);
    });
  });

  group('R13 restart', () {
    testWidgets(
        'restart resets hunter, camera, arrows, aim, and unpauses',
        (tester) async {
      final game = await makeGame(tester);
      addTearDown(game.dispose);
      final spawn = game.hunter.position.clone();

      // 1. Move Hunter.
      game.hunter.position.x = 1200;
      game.hunter.moveDirection = 1;

      // 2. Move camera by running updates.
      for (var i = 0; i < 200; i++) {
        game.update(1 / 60);
      }
      expect(game.camera.viewfinder.position.x, greaterThan(0));

      // 3. Fire multiple arrows.
      game.aim.worldAngle = 0;
      game.aim.power = 0.5;
      for (var i = 0; i < 3; i++) {
        await game.fire(game.aim);
      }
      expect(game.arrows.length, greaterThan(0));

      // 4. Begin an aim gesture state.
      game.aim.active = true;
      game.aim.pullDistance = 30;

      // Pause before restart.
      game.pauseGame();

      // 5. Trigger restart.
      game.restart();

      // 6. Hunter back at spawn, full health.
      expect(game.hunter.position.x, closeTo(spawn.x, 0.001));
      expect(game.hunter.position.y, closeTo(spawn.y, 0.001));
      expect(game.hunter.health, 100);

      // 7. Camera x = 0.
      expect(game.camera.viewfinder.position.x, 0);

      // 8. Zero active arrows.
      expect(game.arrows, isEmpty);

      // 9. Aim inactive + pull reset.
      expect(game.aim.active, isFalse);
      expect(game.aim.pullDistance, 0);

      // 10. Not paused.
      expect(game.paused, isFalse);
      expect(game.pauseNotifier.value, isFalse);
    });
  });
}
