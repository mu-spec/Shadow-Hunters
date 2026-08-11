import 'dart:ui';

import 'package:flame/components.dart';

/// A simple static rectangular obstacle (V1 battlefield geometry).
///
/// Rendered visibly in the world and used for collision:
/// - [segmentIntersectsRect] is used by the game so arrows cannot pass through.
/// - [Rect] overlaps are used to block the Hunter from walking through.
/// Enemies deliberately ignore obstacles (no pathfinding) so they never get
/// stuck; obstacles are placed/spawned to keep them functional.
class Obstacle extends PositionComponent {
  Obstacle({required Rect rect})
      : super(
          position: Vector2(rect.left, rect.top),
          size: Vector2(rect.width, rect.height),
        );

  /// World-space bounds of this obstacle.
  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  /// Returns true if the segment [a]-[b] intersects [rect]. Used to stop an
  /// arrow from passing through a solid obstacle.
  static bool segmentIntersectsRect(Vector2 a, Vector2 b, Rect rect) {
    // Quick rejection: if the segment's bounding box doesn't touch the rect.
    final segMinX = a.x < b.x ? a.x : b.x;
    final segMaxX = a.x > b.x ? a.x : b.x;
    final segMinY = a.y < b.y ? a.y : b.y;
    final segMaxY = a.y > b.y ? a.y : b.y;
    if (segMaxX < rect.left ||
        segMinX > rect.right ||
        segMaxY < rect.top ||
        segMinY > rect.bottom) {
      return false;
    }
    // Endpoint inside the rect.
    if (rect.contains(Offset(a.x, a.y)) || rect.contains(Offset(b.x, b.y))) {
      return true;
    }
    // Check the segment against each edge of the rect (Liang-Barsky style).
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    double t0 = 0, t1 = 1;
    final p = <double>[-dx, dx, -dy, dy];
    final q = <double>[a.x - rect.left, rect.right - a.x, a.y - rect.top, rect.bottom - a.y];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return false; // parallel and outside
      } else {
        final r = q[i] / p[i];
        if (p[i] < 0) {
          if (r > t1) return false;
          if (r > t0) t0 = r;
        } else {
          if (r < t0) return false;
          if (r < t1) t1 = r;
        }
      }
    }
    return t0 <= t1;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // A solid, clearly visible stone/rock obstacle.
    final fill = Paint()..color = const Color(0xFF6E6A62);
    final edge = Paint()
      ..color = const Color(0xFF3E3B36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final top = Paint()..color = const Color(0xFF8C867A);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, edge);
    // A lighter "top face" strip to read as 3D and to stand out from the ground.
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.x - 4, 6),
      top,
    );
    // A few crack marks for texture.
    final crack = Paint()
      ..color = const Color(0xFF4A463F)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.x * 0.3, size.y * 0.4),
        Offset(size.x * 0.55, size.y * 0.6), crack);
    canvas.drawLine(Offset(size.x * 0.6, size.y * 0.3),
        Offset(size.x * 0.75, size.y * 0.5), crack);
  }
}
