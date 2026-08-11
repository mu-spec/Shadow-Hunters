import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'enemy.dart';

/// Second enemy, Milestone 4A.
///
/// A slow-moving, high-health, hard-hitting melee enemy. It reuses the shared
/// [Enemy] combat architecture (same state machine, movement, and head/body
/// hit zones) but is tuned to feel clearly distinct from the [Skeleton]:
/// slower, tougher, a larger target, and a stronger-but-slower attack.
class Zombie extends Enemy {
  Zombie({
    required super.position,
    required super.hunter,
    super.patrolEnabled = false,
    super.battlefieldWidth = worldWidth,
  }) : super(
          size: Vector2(58, 84), // larger target than the Skeleton
          moveSpeed: zombieSpeed,
          attackRange: zombieAttackRange,
          attackCooldown: zombieAttackCooldown,
          attackDamage: zombieAttackDamage,
          maxHealth: zombieMaxHealth,
          bodyDamage: zombieBodyDamage,
          headDamage: zombieHeadDamage,
          headOffsetY: -66, // bigger head sits higher on the taller body
          headRadius: 13,
          bodyTopOffset: -56,
          bodyBottomOffset: -5,
          hurtDuration: zombieHurtDuration,
          deathDuration: zombieDeathDuration,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    final alpha = isDead ? 0.45 : 1.0;

    // Decaying green skin, dark outlines.
    final skin = Paint()
      ..color = hitFlashTimer > 0
          ? Color.fromRGBO(255, 120, 90, alpha)
          : Color.fromRGBO(92, 140, 74, alpha);
    final dark = Paint()
      ..color = Color.fromRGBO(35, 40, 28, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Broad head (larger target) with a smaller zombie "brain" mark.
    canvas.drawOval(Rect.fromCenter(
      center: const Offset(0, -66),
      width: 24,
      height: 20,
    ), skin);
    canvas.drawOval(Rect.fromCenter(
      center: const Offset(0, -66),
      width: 24,
      height: 20,
    ), dark);

    // Torso, heavy shoulders, and shambling arms.
    canvas.drawLine(const Offset(0, -56), const Offset(0, -28), dark);
    canvas.drawLine(const Offset(-11, -48), const Offset(11, -48), dark); // shoulders
    canvas.drawLine(const Offset(0, -28), const Offset(-12, -4), dark);
    canvas.drawLine(const Offset(0, -28), const Offset(12, -4), dark);
    canvas.drawLine(const Offset(-11, -48), const Offset(-19, -30), dark);
    canvas.drawLine(const Offset(11, -48), const Offset(19, -24), dark);
    canvas.restore();
  }
}
