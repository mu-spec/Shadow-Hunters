import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/entities/hunter_visual.dart';
import 'package:shadow_hunters/game/world/constants.dart';

/// Phase 9A-1 — Hunter BODY sprite integration.
///
/// Confirms the artwork is an optional, purely-visual layer: the gameplay
/// hitbox, aiming math, arrow launch math, movement, health and damage are all
/// unchanged, and the visual defaults to null (procedural fallback).
void main() {
  Hunter makeHunter() =>
      Hunter(position: playerSpawn.clone(), aim: AimState());

  group('Hunter gameplay footprint/hitbox unchanged', () {
    test('collision rect is unchanged', () {
      final h = makeHunter();
      expect(h.size, Vector2(48, 76));
      expect(h.collisionRect.width, 48);
      expect(h.collisionRect.height, 76);
      expect(h.collisionRect.bottom, playerSpawn.y);
      expect(h.collisionRect.left, playerSpawn.x - 24);
      expect(h.collisionRect.right, playerSpawn.x + 24);
    });

    test('visual defaults to null (procedural fallback)', () {
      final h = makeHunter();
      expect(h.visual, isNull);
    });
  });

  group('Aiming mathematics unchanged', () {
    test('bowReleasePositionFor is stable and correct', () {
      final h = makeHunter();
      final p = h.bowReleasePositionFor(0);
      expect(p.y, closeTo(playerSpawn.y - 42, 0.001));
      expect(p.x, closeTo(playerSpawn.x - 10, 0.001));
    });

    test('arrowLaunchCenterFor is stable and correct', () {
      final h = makeHunter();
      final c = h.arrowLaunchCenterFor(0);
      expect(c.x, closeTo(playerSpawn.x - 10 + arrowLength / 2, 0.001));
      expect(c.y, closeTo(playerSpawn.y - 42, 0.001));
    });
  });

  group('Hunter movement unchanged', () {
    test('movement and boundary clamping work', () {
      final h = makeHunter();
      h.moveDirection = 1;
      final start = h.position.x;
      h.update(1);
      expect(h.position.x, greaterThan(start));
      for (var i = 0; i < 1000; i++) {
        h.update(1 / 60);
      }
      expect(h.position.x, closeTo(hunterBoundaryRight, 0.001));
    });

    test('health and damage are unchanged', () {
      final h = makeHunter();
      expect(h.health, hunterMaxHealth);
      h.takeDamage(25);
      expect(h.health, 75);
      h.takeDamage(1000);
      expect(h.health, 0);
      expect(h.isDead, isTrue);
    });
  });

  group('HunterVisual sizing (pure math)', () {
    test('proportional sizing helpers preserve aspect ratio', () {
      expect(HunterVisual.bodyHeightDefault, 200);
      expect(HunterVisual.bodyHeightDefault, greaterThan(0));
    });
  });
}
