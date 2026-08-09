import 'dart:math' show pi;

import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  test('speed scales linearly with power', () {
    final a = AimState();
    expect(a.speed, arrowMinSpeed);
    a.power = 1;
    expect(a.speed, arrowMaxSpeed);
    a.power = 0.5;
    expect(a.speed, closeTo((arrowMinSpeed + arrowMaxSpeed) / 2, 0.0001));
  });

  test('defaults are inactive with no power', () {
    final a = AimState();
    expect(a.active, isFalse);
    expect(a.power, 0);
    expect(a.worldAngle, 0);
    expect(a.facing, 1);
  });

  group('pull-back aim mapping (applyPull)', () {
    // The pull vector is dragStart - current. Pulling LEFT produces a positive
    // px, pulling RIGHT produces a negative px; pulling DOWN gives negative py.

    test('pull LEFT -> fires RIGHT (worldAngle 0), facing right', () {
      final a = AimState();
      a.applyPull(50, 0); // pulled left
      expect(a.worldAngle, closeTo(0, 0.001));
      expect(a.facing, 1);
    });

    test('pull RIGHT -> fires LEFT (worldAngle pi), facing left', () {
      final a = AimState();
      a.applyPull(-50, 0); // pulled right
      expect(a.worldAngle, closeTo(pi, 0.001));
      expect(a.facing, -1);
    });

    test('pull DOWN-LEFT -> fires UP-RIGHT', () {
      final a = AimState();
      a.applyPull(50, -30); // pulled down-left
      expect(a.worldAngle, greaterThan(0));
      expect(a.worldAngle, lessThan(pi / 2));
      expect(a.facing, 1);
    });

    test('pull DOWN-RIGHT -> fires UP-LEFT', () {
      final a = AimState();
      a.applyPull(-50, -30); // pulled down-right
      expect(a.worldAngle, greaterThan(pi / 2));
      expect(a.worldAngle, lessThan(pi));
      expect(a.facing, -1);
    });

    test('pull straight DOWN -> fires straight UP (pi/2)', () {
      final a = AimState();
      a.applyPull(0, -50); // pulled straight down
      expect(a.worldAngle, closeTo(pi / 2, 0.001));
    });

    test('pull UP is clamped (never fires downward)', () {
      final a = AimState();
      a.applyPull(0, 50); // pulled up -> would be downward shot, clamped
      // Facing is right (px = 0 handled as >= 0).
      expect(a.facing, 1);
      // worldAngle must not be in the downward range; it is <= pi.
      expect(a.worldAngle, lessThanOrEqualTo(pi));
    });

    test('larger pull magnitude does not change direction (only power)', () {
      final small = AimState()..applyPull(10, -10);
      final large = AimState()..applyPull(100, -100);
      expect(small.worldAngle, closeTo(large.worldAngle, 0.001));
    });
  });

  test('power scales with pull distance and clamps to [0,1]', () {
    final a = AimState();
    a.setPowerByDistance(maxAimPull);
    expect(a.power, 1);
    a.setPowerByDistance(maxAimPull * 2);
    expect(a.power, 1); // clamped
    a.setPowerByDistance(maxAimPull / 2);
    expect(a.power, closeTo(0.5, 0.001));
  });

  group('minimum pull to fire (R10.1)', () {
    test('no pull -> canFire is false (tap fires zero arrows)', () {
      final a = AimState();
      expect(a.pullDistance, 0);
      expect(a.canFire, isFalse);
    });

    test('pull below threshold -> canFire is false', () {
      final a = AimState()..pullDistance = minPullToFire - 5;
      expect(a.canFire, isFalse);
    });

    test('pull at/above threshold -> canFire is true', () {
      final a = AimState()..pullDistance = minPullToFire;
      expect(a.canFire, isTrue);

      final b = AimState()..pullDistance = minPullToFire + 30;
      expect(b.canFire, isTrue);
    });

    test('threshold is small and comfortable (>0)', () {
      expect(minPullToFire, greaterThan(0));
      expect(minPullToFire, lessThan(maxAimPull));
    });
  });
}
