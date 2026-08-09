import 'dart:math' as math;

/// Pure, deterministic horizontal-camera-follow math.
///
/// Kept separate from the game so the follow logic can be unit/integration
/// tested directly against the real code path. All values are in world units.
class CameraFollow {
  CameraFollow._();

  /// Fraction of the visible width at which the Hunter is kept from the left
  /// edge (so ~65% stays ahead of him).
  static const double followOffset = 0.35;

  /// Horizontal dead zone (world units): the camera does not move for tiny
  /// Hunter movements inside this radius of the current follow point.
  static const double deadZone = 24.0;

  /// Exponential smoothing rate: higher = faster/snappier, lower = smoother.
  static const double smoothingRate = 6.0;

  /// Maximum camera X for a given visible world width: the right edge of the
  /// viewport must never pass the right edge of the world. Adapts to any zoom /
  /// aspect ratio (not hardcoded to one phone).
  static double maxCameraX(double visibleWorldWidth, double worldWidth) =>
      (worldWidth - visibleWorldWidth).clamp(0.0, double.infinity).toDouble();

  /// Computes the next camera X and the next camera target X.
  ///
  /// Returns a record `(camX, camTargetX)`.
  static (double, double) next({
    required double hunterX,
    required double camX,
    required double camTargetX,
    required double visibleWorldWidth,
    required double worldWidth,
    required double dt,
  }) {
    final maxCamX = maxCameraX(visibleWorldWidth, worldWidth);
    if (maxCamX == 0) return (0, 0); // world fits entirely: no pan needed.

    // Ideal camera X to keep the Hunter at the follow offset from the left.
    final target = hunterX - followOffset * visibleWorldWidth;

    // Dead zone: only update the target once the Hunter moves far enough from
    // the current follow point, so tiny movements don't nudge the camera.
    var nextTarget = camTargetX;
    if ((target - camX).abs() > deadZone) {
      nextTarget = target;
    }
    nextTarget = nextTarget.clamp(0.0, maxCamX).toDouble();

    // Smooth (frame-rate independent) exponential approach.
    final lerpT = 1 - math.exp(-smoothingRate * dt);
    var nextX = camX + (nextTarget - camX) * lerpT;
    nextX = nextX.clamp(0.0, maxCamX).toDouble();

    return (nextX, nextTarget);
  }
}
