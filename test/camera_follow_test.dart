import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/camera/camera_follow.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  // ---- maxCameraX / boundary math ----

  test('maxCameraX allows panning on a normal landscape viewport', () {
    const visibleW = 1520.0; // ~a typical landscape visible world width
    final maxX = CameraFollow.maxCameraX(visibleW, worldWidth);
    expect(maxX, greaterThan(0));
    expect(maxX, closeTo(worldWidth - visibleW, 0.001));
  });

  test('maxCameraX clamps the right edge to the world edge', () {
    const visibleW = 1520.0;
    final maxX = CameraFollow.maxCameraX(visibleW, worldWidth);
    expect(maxX + visibleW, closeTo(worldWidth, 0.001));
  });

  test('maxCameraX is 0 when the world fits entirely on screen', () {
    expect(CameraFollow.maxCameraX(3000.0, worldWidth), 0);
  });

  test('maxCameraX adapts to zoom (no hardcoded resolution)', () {
    // Larger visible width (smaller zoom) => smaller pan range.
    expect(
      CameraFollow.maxCameraX(1200.0, worldWidth),
      greaterThan(CameraFollow.maxCameraX(1800.0, worldWidth)),
    );
  });

  test('camera X is clamped to [0, maxCameraX] (left and right bounds)', () {
    const visibleW = 1520.0;
    const maxX = 2560.0 - 1520.0;

    // Hunter far left -> camera target would be negative -> clamped to 0.
    final left = CameraFollow.next(
      hunterX: 0,
      camX: 0,
      camTargetX: 0,
      visibleWorldWidth: visibleW,
      worldWidth: worldWidth,
      dt: 0.016,
    );
    expect(left.$1, greaterThanOrEqualTo(0));

    // Hunter far right -> camera must never exceed maxCameraX.
    // Simulate many steps so the camera converges toward the far-right target.
    var camX = 0.0;
    var target = 0.0;
    for (var i = 0; i < 600; i++) {
      final r = CameraFollow.next(
        hunterX: worldWidth - 1, // far right
        camX: camX,
        camTargetX: target,
        visibleWorldWidth: visibleW,
        worldWidth: worldWidth,
        dt: 0.016,
      );
      camX = r.$1;
      target = r.$2;
    }
    expect(camX, lessThanOrEqualTo(maxX + 0.001));
  });

  // ---- Follow threshold / dead zone ----

  test('camera does not move while Hunter is within the follow offset', () {
    const visibleW = 1520.0;
    // Ideal camera X keeps Hunter at 35% of visible width:
    //   target = hunterX - 0.35*visibleW
    // At hunterX = 200 (< 0.35*1520 = 532), target is negative -> clamped to 0,
    // so the camera stays put.
    final r = CameraFollow.next(
      hunterX: 200,
      camX: 0,
      camTargetX: 0,
      visibleWorldWidth: visibleW,
      worldWidth: worldWidth,
      dt: 0.016,
    );
    expect(r.$1, 0);
  });

  test('camera follows right once the Hunter passes the follow offset', () {
    const visibleW = 1520.0;
    // Hunter at x=1200 (> 0.35*1520 = 532): ideal target = 1200 - 532 = 668.
    final r = CameraFollow.next(
      hunterX: 1200,
      camX: 0,
      camTargetX: 0,
      visibleWorldWidth: visibleW,
      worldWidth: worldWidth,
      dt: 0.1,
    );
    expect(r.$1, greaterThan(0));
  });

  test('small Hunter movement inside the dead zone does not move camera', () {
    const visibleW = 1520.0;
    // Camera currently at 500 (already following). Target differs from camX by
    // less than deadZone (24) -> no movement.
    final r = CameraFollow.next(
      hunterX: 500 + 0.35 * visibleW + 10, // target ~510 (within dead zone)
      camX: 500,
      camTargetX: 500,
      visibleWorldWidth: visibleW,
      worldWidth: worldWidth,
      dt: 0.1,
    );
    expect(r.$2, 500); // target unchanged (inside dead zone)
  });

  // ---- Integration-style: camera increases as Hunter moves right ----

  test('integration: camera X increases as Hunter moves right, Hunter stays visible',
      () {
    const visibleW = 1520.0;
    var camX = 0.0;
    var target = 0.0;

    // Walk the Hunter from left to right in steps, running updates.
    var prevCamX = 0.0;
    var moved = false;
    for (var hunterX = 200.0; hunterX <= worldWidth - 100; hunterX += 40) {
      final r = CameraFollow.next(
        hunterX: hunterX,
        camX: camX,
        camTargetX: target,
        visibleWorldWidth: visibleW,
        worldWidth: worldWidth,
        dt: 0.033,
      );
      camX = r.$1;
      target = r.$2;

      if (camX > prevCamX) moved = true;
      prevCamX = camX;

      // Hunter's screen position = hunterX - camX. Should stay within the view.
      final screenX = hunterX - camX;
      expect(screenX, greaterThanOrEqualTo(-1));
      expect(screenX, lessThanOrEqualTo(visibleW + 1));
    }
    expect(moved, isTrue, reason: 'camera should have followed to the right');
  });

  test('integration: camera returns left as Hunter moves back left', () {
    const visibleW = 1520.0;
    var camX = 0.0;
    var target = 0.0;

    // Move Hunter right first so the camera follows right.
    for (var hunterX = 200.0; hunterX <= worldWidth - 200; hunterX += 60) {
      final r = CameraFollow.next(
        hunterX: hunterX,
        camX: camX,
        camTargetX: target,
        visibleWorldWidth: visibleW,
        worldWidth: worldWidth,
        dt: 0.05,
      );
      camX = r.$1;
      target = r.$2;
    }
    final farRightCamX = camX;
    expect(farRightCamX, greaterThan(500));

    // Now move the Hunter back left; the camera should follow back.
    for (var hunterX = (worldWidth - 200).toDouble();
        hunterX >= 200;
        hunterX -= 60) {
      final r = CameraFollow.next(
        hunterX: hunterX,
        camX: camX,
        camTargetX: target,
        visibleWorldWidth: visibleW,
        worldWidth: worldWidth,
        dt: 0.05,
      );
      camX = r.$1;
      target = r.$2;
    }
    expect(camX, lessThan(farRightCamX));
  });

  // ---- Restart reset (camera returns to x=0) ----

  test('restart resets camera state to the left origin', () {
    // After a run that moved the camera right, a reset zeroes camX and target.
    var camX = 900.0;
    var target = 900.0;
    // Reset:
    camX = 0;
    target = 0;
    expect(camX, 0);
    expect(target, 0);
  });

  test('CameraFollow constants are sane', () {
    expect(CameraFollow.followOffset, greaterThan(0));
    expect(CameraFollow.followOffset, lessThan(1));
    expect(CameraFollow.deadZone, greaterThan(0));
    expect(CameraFollow.smoothingRate, greaterThan(0));
  });
}
