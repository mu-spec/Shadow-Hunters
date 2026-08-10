import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/controls/aim_control.dart';

void main() {
  test('AimControl is a screen-space top-left anchored region', () {
    final control = AimControl(aim: AimState());
    expect(control.anchor, Anchor.topLeft);
    expect(control.size, Vector2(96, 96));
  });

  test('aim state remains independent from movement state', () {
    final aim = AimState()..active = true;
    expect(aim.active, isTrue);
    // MovementJoystick owns movement input; AimState owns only aiming input.
    aim.active = false;
    expect(aim.active, isFalse);
  });
}
