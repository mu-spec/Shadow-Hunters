import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../world/constants.dart';

class CombatFeedback extends PositionComponent {
  CombatFeedback({required super.position, required this.damage, required this.headshot})
      : super(anchor: Anchor.center);

  final int damage;
  final bool headshot;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= 28 * dt;
    if (_age >= combatFeedbackDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final opacity = (1 - _age / combatFeedbackDuration).clamp(0.0, 1.0);
    final text = headshot ? 'HEADSHOT  $damage' : '$damage';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: headshot
              ? Color.fromRGBO(255, 220, 60, opacity)
              : Color.fromRGBO(255, 255, 255, opacity),
          fontSize: headshot ? 16 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}

class ImpactEffect extends PositionComponent {
  ImpactEffect({required super.position, required this.headshot})
      : super(anchor: Anchor.center);

  final bool headshot;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= 0.22) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_age / 0.22).clamp(0.0, 1.0);
    final radius = headshot ? 18.0 : 11.0;
    final paint = Paint()
      ..color = (headshot ? const Color(0xFFFFD43B) : const Color(0xFFFFFFFF))
          .withOpacity(1 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headshot ? 4 : 2;
    canvas.drawCircle(Offset.zero, radius * progress, paint);
  }
}
