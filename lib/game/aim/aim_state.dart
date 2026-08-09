import 'dart:math' show atan2, pi;

import '../world/constants.dart';

/// Minimum pull distance (touch units) required before a shot may be fired.
/// A tap or tiny accidental finger movement below this produces no Arrow.
const double minPullToFire = 14.0;

/// Mutable aim state shared between the pull-back aim control (input) and the
/// hunter (render) / arrow (launch).
///
/// The aim is stored as an *absolute* [worldAngle] (0 = firing right, + = firing
/// upward, up to pi = firing left) and a [power] (0..1). The firing direction is
/// the opposite of the drag/pull direction (pull-back bow controls).
class AimState {
  /// Whether the player is currently aiming.
  bool active = false;

  /// Absolute world aim angle (0 = right, + = up, pi = left).
  double worldAngle = 0;

  /// Hunter facing derived from the shot direction (+1 right, -1 left).
  double facing = 1;

  /// Shot power in [0, 1].
  double power = 0;

  /// The pull distance (touch units) for the current aim gesture.
  double pullDistance = 0;

  /// Whether the current pull has reached the minimum threshold to fire.
  bool get canFire => pullDistance >= minPullToFire;

  /// Projectile speed for the current power.
  double get speed => arrowMinSpeed + power * (arrowMaxSpeed - arrowMinSpeed);

  /// Sets the aim from a *pull* vector (dragStart - current).
  ///
  /// The shot flies in the pull direction (opposite the finger drag), so
  /// pulling left fires right, pulling down-left fires up-right, etc. The shot
  /// is clamped to the upper hemisphere (no downward firing); [facing] follows
  /// the horizontal shot direction.
  void applyPull(double px, double py) {
    // Up is negative y in world/screen coords. Clamp so we never fire downward.
    double vy = py;
    if (vy > 0) vy = 0;

    worldAngle = atan2(-vy, px);
    // Normalize to [0, 2*pi) so a straight-left pull yields +pi (not -pi,
    // which atan2 can return when vy is -0.0).
    if (worldAngle < 0) worldAngle += 2 * pi;
    facing = px >= 0 ? 1 : -1;
  }

  /// Sets power from the pull distance (clamped to [0, 1]).
  void setPowerByDistance(double distance) {
    power = (distance / maxAimPull).clamp(0.0, 1.0).toDouble();
  }
}
