import 'dart:ui';

import 'package:flame/components.dart';

import 'constants.dart';

/// World boundaries for the battlefield.
///
/// Draws a *very thin, faint* outline at the world edges to mark the limits
/// without cluttering the view (the thick red version became a giant slab once
/// the camera zoomed to fill the screen). The bottom is bounded by the ground.
/// In later milestones these edges will act as physical collision walls.
class WorldBounds extends PositionComponent {
  WorldBounds({double width = worldWidth, double height = worldHeight})
      : super(size: Vector2(width, height), position: Vector2.zero());

  static const double _lineWidth = 2;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = wallColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth;

    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(bounds, paint);
  }
}
