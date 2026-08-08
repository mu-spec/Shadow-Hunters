import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../shadow_hunters_game.dart';

/// Fills the entire viewport with a simple forest-night background color.
///
/// Renders against `game.size` at draw time so it always covers the screen
/// regardless of when it is added to the world.
class ArenaBackground extends Component with HasGameReference<ShadowHuntersGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final s = game.size;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.x, s.y),
      Paint()..color = const Color(0xFF18202B),
    );
  }
}
