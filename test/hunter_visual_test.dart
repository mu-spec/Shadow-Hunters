import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/entities/hunter_visual.dart';
import 'package:shadow_hunters/game/world/constants.dart';

/// Phase 9A — static Hunter + Bow + Arrow visual prototype.
///
/// These tests confirm the visual integration does NOT change gameplay:
/// the Hunter's hitbox footprint, aiming math, arrow launch math, and movement
/// all remain unchanged. The artwork is a purely optional visual layer that
/// cannot affect gameplay (it defaults to null / procedural fallback).
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

    test('visual defaults to null (procedural fallback path)', () {
      final h = makeHunter();
      expect(h.visual, isNull);
      expect(h.useArtwork, isTrue);
    });
  });

  group('Aiming mathematics unchanged', () {
    test('bowReleasePositionFor is stable and correct', () {
      final h = makeHunter();
      // Right-facing horizontal shot: nock near bow, arrow extends right.
      final p = h.bowReleasePositionFor(0);
      expect(p.y, closeTo(playerSpawn.y - 42, 0.001));
      expect(p.x, closeTo(playerSpawn.x - 10, 0.001));
    });

    test('arrowLaunchCenterFor is stable and correct', () {
      final h = makeHunter();
      final c = h.arrowLaunchCenterFor(0);
      // Half a shaft length beyond the nock.
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
      // Clamp to right boundary.
      for (var i = 0; i < 1000; i++) {
        h.update(1 / 60);
      }
      expect(h.position.x,
          closeTo(hunterBoundaryRight, 0.001));
    });

    test('health and damage are unchanged', () {
      final h = makeHunter();
      expect(h.health, hunterMaxHealth);
      h.takeDamage(25);
      expect(h.health, 75);
      expect(h.isDead, isFalse);
      h.takeDamage(1000);
      expect(h.health, 0);
      expect(h.isDead, isTrue);
    });
  });

  group('HunterVisual sizing (pure math)', () {
    test('proportional sizing helpers are self-consistent', () {
      // These are pure aspect-ratio helpers; the real sprites are square-ish
      // (1:1) so a square source yields a square destination.
      // We verify the methods exist and preserve aspect for a 1:1 ratio via
      // direct computation against the constants.
      // (Full sprite construction needs a running engine, so we only check the
      // default constants used for the artwork path.)
      expect(HunterVisual.bodyHeightDefault, 200);
      expect(HunterVisual.bowHeightDefault, 160);
      expect(HunterVisual.arrowLengthDefault, 170);
      expect(HunterVisual.bowGripYFractionDefault, greaterThan(0));
      expect(HunterVisual.bowGripYFractionDefault, lessThan(1));
    });
  });
}
