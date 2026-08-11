import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'enemy.dart';

// Re-export the legacy Skeleton enum names for code/tests that import
// skeleton.dart directly (they alias the shared Enemy enums).
export 'enemy.dart' show SkeletonState, SkeletonHitZone;

/// Basic melee enemy for Milestone 2A.
///
/// Reuses the shared [Enemy] combat architecture with its own stats and look.
class Skeleton extends Enemy {
  Skeleton({
    required super.position,
    required super.hunter,
    super.patrolEnabled = false,
    super.battlefieldWidth = worldWidth,
    super.obstacles = const [],
  }) : super(
          size: Vector2(44, 72),
          moveSpeed: skeletonSpeed,
          attackRange: skeletonAttackRange,
          attackCooldown: skeletonAttackCooldown,
          attackDamage: skeletonAttackDamage,
          maxHealth: skeletonMaxHealth,
          bodyDamage: skeletonBodyDamage,
          headDamage: skeletonHeadDamage,
          headOffsetY: -58,
          headRadius: 11,
          bodyTopOffset: -49,
          bodyBottomOffset: -4,
          hurtDuration: skeletonHurtDuration,
          deathDuration: skeletonDeathDuration,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    final alpha = isDead ? 0.45 : 1.0;
    final bone = Paint()
      ..color = hitFlashTimer > 0
          ? Color.fromRGBO(255, 105, 105, alpha)
          : Color.fromRGBO(220, 220, 200, alpha);
    final dark = Paint()
      ..color = Color.fromRGBO(45, 42, 48, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(const Offset(0, -58), 10, bone);
    canvas.drawLine(const Offset(0, -48), const Offset(0, -25), dark);
    canvas.drawLine(const Offset(-10, -42), const Offset(10, -34), dark);
    canvas.drawLine(const Offset(0, -25), const Offset(-9, -3), dark);
    canvas.drawLine(const Offset(0, -25), const Offset(9, -3), dark);
    canvas.drawLine(const Offset(-10, -42), const Offset(-17, -24), dark);
    canvas.drawLine(const Offset(10, -34), const Offset(17, -18), dark);
    canvas.restore();
  }
}
