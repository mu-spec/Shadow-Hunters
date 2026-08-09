import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

/// Builds the on-screen joystick used for hunter movement.
///
/// A touch/drag joystick placed at the bottom-left of the landscape screen —
/// the classic mobile movement control. Reading [direction] / [relativeDelta]
/// drives the hunter.
class MovementJoystick extends JoystickComponent {
  MovementJoystick()
      : super(
          background: _CircleVisual(
            radius: 42,
            color: const Color(0x442B3A46),
            stroke: 2,
          ),
          knob: _CircleVisual(
            radius: 22,
            color: const Color(0xB37FD44E),
            stroke: 2,
          ),
          knobRadius: 22,
          size: 84,
          anchor: Anchor.bottomLeft,
          margin: const EdgeInsets.only(left: 28, bottom: 28),
          priority: 10,
        );

  /// Horizontal movement input in [-1, 0, +1].
  ///
  /// Returns -1 (left), +1 (right) or 0 (idle). Vertical input is ignored for
  /// this 2D side-view milestone.
  int get horizontalDirection {
    final d = direction;
    switch (d) {
      case JoystickDirection.left:
      case JoystickDirection.upLeft:
      case JoystickDirection.downLeft:
        return -1;
      case JoystickDirection.right:
      case JoystickDirection.upRight:
      case JoystickDirection.downRight:
        return 1;
      default:
        return 0;
    }
  }
}

/// A simple filled circle used for the joystick's knob and background.
class _CircleVisual extends PositionComponent {
  _CircleVisual({
    required this.radius,
    required this.color,
    this.stroke = 0,
  }) : super(size: Vector2.all(radius * 2));

  final double radius;
  final Color color;
  final double stroke;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = color
      ..style = stroke > 0 ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = stroke;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius - (stroke > 0 ? stroke / 2 : 0.0),
      paint,
    );
  }
}
