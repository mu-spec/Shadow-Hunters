import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../shadow_hunters_game.dart';

/// Centers the "Shadow Hunters Game World" title text on screen.
///
/// Uses Flutter's [TextPainter] so the layout always fits the current viewport.
class ArenaTitle extends Component with HasGameReference<ShadowHuntersGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final s = game.size;
    final painter = TextPainter(
      text: const TextSpan(
        text: 'Shadow Hunters Game World',
        style: TextStyle(
          color: Color(0xFFE8F0F5),
          fontSize: 46,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(s.x / 2 - painter.width / 2, s.y / 2 - painter.height / 2),
    );
  }
}
