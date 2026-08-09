import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../shadow_hunters_game.dart';

/// Pause/resume toggle for the game (top-right of the screen).
///
/// Uses Flame's real engine pause (`pauseEngine()` / `resumeEngine()`), which
/// stops the whole update loop — freezing Hunter movement, arrows, gravity,
/// camera follow and timers. When paused, Flame's GameWidget does not call
/// `update()`, so the game freezes exactly where it is and resumes with no
/// delta-time jump.
class PauseButton extends PositionComponent
    with
        HasGameReference<ShadowHuntersGame>,
        ComponentViewportMargin<ShadowHuntersGame>,
        TapCallbacks {
  PauseButton()
      : super(
          size: Vector2(40, 40),
          anchor: Anchor.topRight,
          priority: 20,
        ) {
    // `margin` lives on ComponentViewportMargin (not PositionComponent), so it
    // must be set here in the constructor body rather than passed to super.
    // Compact size + safe margin from the top/right screen edges.
    margin = const EdgeInsets.only(top: 12, right: 12);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.paused) {
      game.resumeGame();
    } else {
      game.pauseGame();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = Offset(size.x / 2, size.y / 2);

    canvas.drawCircle(
      c,
      size.x / 2,
      Paint()..color = const Color(0x660B1016),
    );
    canvas.drawCircle(
      c,
      size.x / 2,
      Paint()
        ..color = const Color(0xBB7FD44E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final icon = Paint()..color = const Color(0xFFE8F0F5);
    if (game.paused) {
      // Play triangle.
      final path = Path()
        ..moveTo(c.dx - 6, c.dy - 9)
        ..lineTo(c.dx + 10, c.dy)
        ..lineTo(c.dx - 6, c.dy + 9)
        ..close();
      canvas.drawPath(path, icon);
    } else {
      // Pause bars.
      canvas.drawRect(Rect.fromLTWH(c.dx - 8, c.dy - 9, 5, 18), icon);
      canvas.drawRect(Rect.fromLTWH(c.dx + 3, c.dy - 9, 5, 18), icon);
    }
  }
}
