import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextDirection, TextPainter, TextSpan, TextStyle;

/// A prototype marker showing where a character will spawn.
///
/// Draws a target ring with a crosshair plus a text label beneath it. Used for
/// the player and enemy spawn points in this milestone (no characters yet).
class SpawnMarker extends PositionComponent {
  SpawnMarker({
    required super.position,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  static const double radius = 26;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(0, 0);

    // Outer ring.
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner dot.
    canvas.drawCircle(center, 4, Paint()..color = color);

    // Crosshair ticks.
    final tick = Paint()..color = color;
    canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), tick..strokeWidth = 2);
    canvas.drawLine(Offset(0, -radius), Offset(0, radius), tick..strokeWidth = 2);

    // Label beneath the marker.
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(-painter.width / 2, radius + 8),
    );
  }
}
