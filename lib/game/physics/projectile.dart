import 'dart:math' show sqrt;

import 'package:flame/components.dart' show Vector2;

/// Pure, side-effect-free projectile math used by both the flying Arrow and the
/// trajectory preview, so the two always agree. Gravity is positive downward in
/// Flame's coordinate system (+y is down).
class Projectile {
  /// Position of a projectile at time [t] given [start] (in world coords),
  /// initial [velocity] (px/s) and constant [gravity] (px/s², positive down).
  ///
  ///   p(t) = start + velocity * t + (0, 0.5 * gravity * t²)
  static Vector2 position(
    Vector2 start,
    Vector2 velocity,
    double gravity,
    double t,
  ) {
    return start +
        velocity * t +
        Vector2(0, 0.5 * gravity * t * t);
  }

  /// First non-negative time `t` at which a projectile starting at [startY]
  /// with vertical velocity [vy] (positive = down) crosses [targetY].
  ///
  /// Returns `null` if it never reaches [targetY]. Solves the quadratic
  /// `0.5*g*t² + vy*t + (startY - targetY) = 0` and picks the smallest valid
  /// root.
  static double? timeToReachY(
    double startY,
    double vy,
    double gravity,
    double targetY,
  ) {
    final a = 0.5 * gravity;
    final b = vy;
    final c = startY - targetY;
    if (a == 0) {
      // No gravity: linear vertical motion.
      if (b == 0) return null;
      final t = -c / b;
      return t >= 0 ? t : null;
    }
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null; // never reaches targetY

    final sqrtD = sqrt(disc);
    final t1 = (-b - sqrtD) / (2 * a);
    final t2 = (-b + sqrtD) / (2 * a);

    double? best;
    for (final t in [t1, t2]) {
      if (t >= 0 && (best == null || t < best)) best = t;
    }
    return best;
  }

  /// Horizontal range when the projectile drops from [startY] to [targetY]
  /// (i.e. its landing distance from [start]'s x). Convenience for tests.
  static double rangeToY(
    Vector2 start,
    Vector2 velocity,
    double gravity,
    double targetY,
  ) {
    final t = timeToReachY(start.y, velocity.y, gravity, targetY);
    if (t == null) return double.infinity;
    return position(start, velocity, gravity, t).x - start.x;
  }
}
