import 'dart:math' show cos, pi, sin;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  test('hunter has full health and reasonable speed', () {
    expect(hunterMaxHealth, 100);
    expect(hunterSpeed, greaterThan(0));
  });

  test('boundary clamps keep the hunter inside the battlefield', () {
    // Left and right limits must be inside the world and ordered.
    expect(hunterBoundaryLeft, greaterThan(wallThickness));
    expect(hunterBoundaryRight, lessThan(worldWidth - wallThickness));
    expect(hunterBoundaryLeft, lessThan(hunterBoundaryRight));
  });

  test('player spawn rests on the ground', () {
    expect(playerSpawn.y, groundY);
    expect(enemySpawn.y, groundY);
  });

  group('bow release point (R15)', () {
    Hunter makeHunter(Vector2 pos) => Hunter(position: pos, aim: AimState());

    test('right-facing horizontal shot: nock at bow, arrow extends right',
        () {
      final h = makeHunter(playerSpawn);
      const angle = 0.0; // firing right
      final center = h.arrowLaunchCenterFor(angle);
      // Nock = center - dir*arrowLength/2 should equal bow release point.
      final nock = center - Vector2(1, 0) * (arrowLength / 2);
      expect(nock, closeToVector(h.bowReleasePositionFor(angle)));
      // Release point is ~10 behind the bow pivot (which is 42 above feet).
      expect(h.bowReleasePositionFor(angle).x, closeTo(h.position.x - 10, 0.1));
      expect(h.bowReleasePositionFor(angle).y, closeTo(h.position.y - 42, 0.1));
    });

    test('left-facing horizontal shot mirrors to the left side', () {
      final h = makeHunter(playerSpawn);
      const angle = pi; // firing left
      final center = h.arrowLaunchCenterFor(angle);
      final nock = center - Vector2(-1, 0) * (arrowLength / 2);
      expect(nock, closeToVector(h.bowReleasePositionFor(angle)));
      // Mirrored: release point is to the left of the pivot.
      expect(h.bowReleasePositionFor(angle).x, closeTo(h.position.x + 10, 0.1));
    });

    test('upward shot release point is above the pivot', () {
      final h = makeHunter(playerSpawn);
      const angle = pi / 2; // straight up
      // Release point = pivot (42 above feet) pulled back 10 opposite the
      // firing direction. Firing up, "back" is down, so y = 600-42+10 = 568.
      expect(h.bowReleasePositionFor(angle).y, closeTo(600 - 42 + 10, 0.1));
    });

    test('release point tracks the Hunter when he moves', () {
      final h = makeHunter(playerSpawn);
      h.position.x = 900; // moved right
      const angle = 0.0;
      expect(h.bowReleasePositionFor(angle).x, closeTo(900 - 10, 0.1));
    });
  });

  group('bow draw tension (R16)', () {
    Hunter makeHunter() => Hunter(position: playerSpawn, aim: AimState());

    test('bowDraw is 0 when not aiming', () {
      final h = makeHunter();
      h.aim.active = false;
      expect(h.bowDraw, 0);
    });

    test('bowDraw grows with aim power', () {
      final h = makeHunter();
      h.aim.active = true;
      h.aim.power = 0;
      expect(h.bowDraw, 0);
      h.aim.power = 0.5;
      expect(h.bowDraw, closeTo(bowMaxDraw * 0.5, 0.001));
      h.aim.power = 1;
      expect(h.bowDraw, closeTo(bowMaxDraw, 0.001));
    });

    test('draw pulls the launch origin back (continuous with nocked arrow)',
        () {
      final h = makeHunter();
      h.aim.active = true;
      const angle = 0.0;

      final noDraw = h.arrowLaunchCenterFor(angle);
      h.aim.power = 1.0;
      final fullDraw = h.arrowLaunchCenterFor(angle);
      // Higher draw pulls the launch origin back along -dir (x decreases).
      expect(fullDraw.x, lessThan(noDraw.x));
    });
  });

  group('exact arrow nock alignment (R18)', () {
    Hunter makeHunter(Vector2 pos) => Hunter(position: pos, aim: AimState());

    // For a given angle, the real Arrow's rear nock must equal the bow release
    // point. arrowLaunchCenterFor returns the CENTER; the nock is center - dir*L/2.
    Vector2 arrowNock(Vector2 pos, double angle) {
      final h = makeHunter(pos);
      final dir = Vector2(cos(angle), -sin(angle));
      return h.arrowLaunchCenterFor(angle) - dir * (arrowLength / 2);
    }

    void expectNockAtBow(Vector2 pos, double angle) {
      final h = makeHunter(pos);
      final nock = arrowNock(pos, angle);
      expect(nock, closeToVector(h.bowReleasePositionFor(angle)));
    }

    test('horizontal right shot: nock exactly at bow release', () {
      expectNockAtBow(playerSpawn, 0.0);
    });

    test('upward-right shot: nock exactly at bow release', () {
      expectNockAtBow(playerSpawn, pi / 4);
    });

    test('steep-right shot: nock exactly at bow release', () {
      expectNockAtBow(playerSpawn, pi / 6);
    });

    test('horizontal left shot: nock exactly at bow release (mirrored)', () {
      expectNockAtBow(playerSpawn, pi);
    });

    test('upward-left shot: nock exactly at bow release (mirrored)', () {
      expectNockAtBow(playerSpawn, 3 * pi / 4);
    });

    test('Hunter moved far right: nock still at bow (camera-follow aware)', () {
      expectNockAtBow(Vector2(1800, groundY), 0.0);
    });
  });
}

/// Custom matcher comparing two Vector2s.
Matcher closeToVector(Vector2 expected, {double epsilon = 0.1}) =>
    _CloseToVector(expected, epsilon);

class _CloseToVector extends Matcher {
  final Vector2 expected;
  final double epsilon;
  _CloseToVector(this.expected, this.epsilon);

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is Vector2 &&
      (item - expected).length <= epsilon;

  @override
  Description describe(Description description) =>
      description.add('a Vector2 within $epsilon of $expected');
}
