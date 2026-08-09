import 'dart:math' show cos, pi, sin;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/physics/projectile.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  // A strong (flat) shot: full power, angle 0 (facing right).
  Vector2 flatShot({double power = 1.0}) {
    final speed = arrowMinSpeed + power * (arrowMaxSpeed - arrowMinSpeed);
    return Vector2(speed, 0);
  }

  Vector2 angledShot(double angleRad, {double power = 1.0}) {
    final speed = arrowMinSpeed + power * (arrowMaxSpeed - arrowMinSpeed);
    return Vector2(cos(angleRad), -sin(angleRad)) * speed;
  }

  test('projectile position follows quadratic gravity', () {
    final start = Vector2(0, 0);
    final vel = Vector2(100, 0); // horizontal, no initial vertical velocity
    const t = 2.0;
    final p = Projectile.position(start, vel, arrowGravity, t);

    // x = 100*2 = 200; y = 0.5 * 900 * 4 = 1800 (falling down = +y).
    expect(p.x, closeTo(200, 0.001));
    expect(p.y, closeTo(0.5 * arrowGravity * t * t, 0.001));
  });

  test('weak shot travels a shorter distance than a strong shot', () {
    const launchY = groundY - 100.0;
    const targetY = groundY;

    final startWeak = Vector2(0, launchY);
    final startStrong = Vector2(0, launchY);

    final rWeak = Projectile.rangeToY(
        startWeak, flatShot(power: 0.2), arrowGravity, targetY);
    final rStrong = Projectile.rangeToY(
        startStrong, flatShot(power: 1.0), arrowGravity, targetY);

    expect(rWeak, lessThan(rStrong));
    expect(rStrong, greaterThan(rWeak));
    // Strong shot should reach a substantial horizontal distance.
    expect(rStrong, greaterThan(rWeak * 2));
  });

  test('a steep upward shot still eventually lands (time to ground > 0)', () {
    final start = Vector2(0, groundY - 100.0);
    // Shooting up at 60°.
    final vel = angledShot(pi / 3, power: 0.8);
    final t = Projectile.timeToReachY(
        start.y, vel.y, arrowGravity, groundY);
    expect(t, isNotNull);
    expect(t!, greaterThan(0));
    // Position at that time should be at/just below the ground.
    final p = Projectile.position(start, vel, arrowGravity, t);
    expect(p.y, greaterThanOrEqualTo(groundY - 1));
  });

  test('timeToReachY returns null when it never reaches the target', () {
    // Starting below the target with a velocity that never rises above it and
    // no gravity pulling down to it (e.g. firing downward away from a target
    // far below with huge gravity is contrived); simplest: target above start,
    // moving down with zero gravity.
    final t = Projectile.timeToReachY(100, 10, 0, 50); // target at 50 (above? no, 50<100 means target is higher/less y)
    // Target y=50 is above start y=100 and projectile moves down (vy=10>0),
    // so it moves away and never reaches y=50.
    expect(t, isNull);
  });
}
