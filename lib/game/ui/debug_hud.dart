import 'dart:math' show pi;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextDirection, TextPainter, TextSpan, TextStyle;

import '../shadow_hunters_game.dart';

/// On-screen debug text showing the current aim state and the last fired shot.
///
/// Screen-space (added to the game root), so it stays fixed on screen. Used to
/// verify that aiming direction/power and the release (fire) event work.
class DebugHud extends PositionComponent with HasGameReference<ShadowHuntersGame> {
  DebugHud()
      : super(
          position: Vector2(150, 20),
          size: Vector2(700, 60),
          priority: 30,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final g = game;

    if (!g.showDebugHud && g.statusNotifier.value == GameStatus.playing) {
      final objective = g.levelData.objective;
      final text = 'LEVEL ${g.levelNumber}   HEALTH ${g.hunter.health}   ENEMIES ${g.liveEnemies}${objective == null ? '' : '   $objective'}';
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(color: Color(0xFFE8F0F5), fontSize: 16, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset.zero);
      return;
    }
    if (!g.showDebugHud) return;

    final deg = (g.aim.worldAngle * 180 / pi);
    final text = g.paused
        ? 'PAUSED'
        : 'arrows ${g.arrows.length}  '
            'AIM ${g.aim.active ? "ACTIVE" : "off"}  '
            'angle ${deg.toStringAsFixed(0)}°  '
            'power ${g.aim.power.toStringAsFixed(2)}  '
            'last: ${g.lastShot}';

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFB8C6D2),
          fontSize: 16,
          backgroundColor: Color(0x660B1016),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset.zero);
  }
}
