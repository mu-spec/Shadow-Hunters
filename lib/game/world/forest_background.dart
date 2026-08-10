import 'dart:ui';

import 'package:flame/components.dart';

import 'constants.dart';

/// Prototype night-forest background that fills the whole battlefield.
///
/// Drawn procedurally: a vertical sky gradient, a moon, scattered stars, a
/// distant forest silhouette and a few nearer tree trunks. Purely decorative —
/// used to verify the world renders at the right coordinates and size.
class ForestBackground extends PositionComponent {
  ForestBackground({double width = worldWidth, double height = worldHeight})
      : super(size: Vector2(width, height), position: Vector2.zero());

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final ground = size.y - groundHeight;

    // 1. Sky gradient (top -> bottom).
    final skyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final skyPaint = Paint()
      ..shader = Gradient.linear(
        Offset(0, 0),
        Offset(0, size.y),
        [skyTop, skyBottom],
      );
    canvas.drawRect(skyRect, skyPaint);

    // 2. Moon.
    canvas.drawCircle(
      Offset(size.x * 0.72, 110),
      42,
      Paint()..color = const Color(0xFFE8E4C8),
    );

    // 3. Stars (deterministic pseudo-random scatter).
    final starPaint = Paint()..color = const Color(0xFFCDE3EE);
    for (var i = 0; i < 70; i++) {
      // Use a simple hash of i for a stable, fixed star field.
      final x = ((i * 7919) % size.x.toInt()).toDouble();
      final y = 20 + ((i * 104729) % 380).toDouble();
      final r = 1.0 + (i % 3);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // 4. Distant tree silhouette (a jagged canopy across the horizon).
    final canopy = Path()..moveTo(0, ground);
    for (double x = 0; x <= size.x; x += 60) {
      final h = 90 + ((x * 0.13) % 70);
      canopy.lineTo(x, ground - h);
      canopy.lineTo(x + 30, ground - h * 0.6);
    }
    canopy.lineTo(size.x, ground);
    canopy.close();
    canvas.drawPath(canopy, Paint()..color = treeSilhouette);

    // 5. A few nearer tree trunks on the world edges (frame the scene).
    final trunkPaint = Paint()..color = treeSilhouette;
    for (final x in [90.0, 160.0, size.x - 90, size.x - 160]) {
      canvas.drawRect(
        Rect.fromLTWH(x - 10, ground - 180, 20, 180),
        trunkPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, ground - 185),
          width: 90,
          height: 120,
        ),
        trunkPaint,
      );
    }
  }
}
