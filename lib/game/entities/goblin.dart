import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'enemy.dart';

/// Third and final normal V1 enemy (Milestone 5A).
///
/// A fast, fragile melee enemy. Compared to the Skeleton and Zombie it is the
/// smallest target, has the lowest health, moves the fastest, and attacks the
/// fastest with light damage. It reuses the shared [Enemy] combat pipeline
/// (same state machine, movement, hit zones, damage resolution) but enables
/// the optional telegraphed dodge hop so it occasionally sidesteps.
class Goblin extends Enemy {
  Goblin({
    required super.position,
    required super.hunter,
    super.patrolEnabled = false,
    super.battlefieldWidth = worldWidth,
    super.obstacles = const [],
  }) : super(
          size: Vector2(36, 56), // smaller target than the Skeleton (44x72)
          moveSpeed: goblinSpeed,
          attackRange: goblinAttackRange,
          attackCooldown: goblinAttackCooldown,
          attackDamage: goblinAttackDamage,
          maxHealth: goblinMaxHealth,
          bodyDamage: goblinBodyDamage,
          headDamage: goblinHeadDamage,
          headOffsetY: -44,
          headRadius: 9,
          bodyTopOffset: -37,
          bodyBottomOffset: -4,
          hurtDuration: goblinHurtDuration,
          deathDuration: goblinDeathDuration,
          // Enable the telegraphed dodge.
          dodgeEnabled: true,
          dodgeCooldown: goblinDodgeCooldown,
          dodgeDistance: goblinDodgeDistance,
          dodgeSpeed: goblinDodgeSpeed,
          dodgeTelegraphDuration: goblinDodgeTelegraphDuration,
          dodgeIntervalMin: goblinDodgeIntervalMin,
          dodgeIntervalMax: goblinDodgeIntervalMax,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    final alpha = isDead ? 0.45 : 1.0;

    // Telegraph tint: flash a warning color during the dodge windup.
    final warn = Paint()
      ..color = isDodgeTelegraph
          ? const Color(0xFFFFCC33)
          : (hitFlashTimer > 0
              ? const Color(0xFFFF6B6B)
              : const Color(0xFF8FD07B));
    final dark = Paint()
      ..color = Color.fromRGBO(40, 40, 24, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Small head (smaller target).
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -44), width: 18, height: 16),
      warn,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -44), width: 18, height: 16),
      dark,
    );

    // Pointy goblin ears.
    canvas.drawLine(const Offset(-9, -46), const Offset(-14, -38), dark);
    canvas.drawLine(const Offset(9, -46), const Offset(14, -38), dark);

    // Small, hunched torso and arms.
    canvas.drawLine(const Offset(0, -37), const Offset(0, -14), dark);
    canvas.drawLine(const Offset(0, -14), const Offset(-8, -2), dark);
    canvas.drawLine(const Offset(0, -14), const Offset(8, -2), dark);
    canvas.restore();
  }
}
