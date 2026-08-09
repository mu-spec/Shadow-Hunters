import 'dart:ui';

import 'package:flame/components.dart';

import 'constants.dart';

/// The visible ground band along the bottom of the battlefield.
///
/// A simple grass strip over a dirt base. Marks the lowest walkable surface
/// for the prototype (no player movement yet).
class Ground extends PositionComponent {
  Ground()
      : super(
          position: Vector2(0, groundY),
          size: Vector2(worldWidth, groundHeight),
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = worldWidth;
    final h = groundHeight;

    // Dirt base.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = groundDirt,
    );

    // Grass strip on top.
    const grassHeight = 42.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, grassHeight),
      Paint()..color = groundGrass,
    );

    // A soft boundary line between grass and dirt.
    canvas.drawRect(
      Rect.fromLTWH(0, grassHeight, w, 3),
      Paint()..color = const Color(0xFF233B1F),
    );

    // Sparse grass tufts.
    final tuftPaint = Paint()..color = const Color(0xFF3E5A33);
    for (var i = 0; i < 40; i++) {
      final x = ((i * 3571) % w.toInt()).toDouble();
      final y = 8 + (i % 24).toDouble();
      canvas.drawLine(
        Offset(x, y + 8),
        Offset(x + 3, y),
        tuftPaint..strokeWidth = 2,
      );
    }
  }
}
