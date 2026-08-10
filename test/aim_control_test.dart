import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/controls/aim_control.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  test('AimControl is centered and sized from Hunter body bounds', () {
    final hunter = Hunter(position: playerSpawn, aim: AimState());
    final rect = hunter.aimTouchRect;
    final control = AimControl(
      aim: hunter.aim,
      size: Vector2(rect.width, rect.height),
    )..position = Vector2(rect.center.dx, rect.center.dy);

    expect(control.anchor, Anchor.center);
    expect(control.size.x, closeTo(rect.width, 0.001));
    expect(control.size.y, closeTo(rect.height, 0.001));
    expect(control.position.x, closeTo(rect.center.dx, 0.001));
    expect(control.position.y, closeTo(rect.center.dy, 0.001));
  });

  test('pull direction is inverse of drag direction and power grows with pull', () {
    final aim = AimState();
    aim.applyPull(40, 0); // drag right means pull vector points left/right mapping
    expect(aim.worldAngle, closeTo(0, 0.001));
    aim.setPowerByDistance(80);
    final shorter = aim.power;
    aim.setPowerByDistance(160);
    expect(aim.power, greaterThan(shorter));
  });
}
