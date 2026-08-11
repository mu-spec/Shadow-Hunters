import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'enemy.dart';
import 'hunter.dart';

/// Callback used by the boss to ask the game to spawn a ranged projectile.
/// [from] is the launch origin (world), [dir] is a normalized direction.
typedef BossRangedFire = void Function(Vector2 from, Vector2 dir);

/// The only V1 boss — Milestone 7A.
///
/// A large, slow, high-health Forest Guardian with a strong melee attack and
/// one simple, clearly-telegraphed ranged attack. Its head is a weak point
/// that deals bonus damage. AI is simple and predictable: no phases, no
/// minions, no transformations, no magic, no status effects.
class ForestGuardian extends Enemy {
  ForestGuardian({
    required super.position,
    required super.hunter,
    this.onRangedFire,
    super.battlefieldWidth = worldWidth,
    super.obstacles = const [],
  }) : super(
          size: Vector2(120, 180), // large enemy
          moveSpeed: bossSpeed,
          attackRange: bossAttackRange,
          attackCooldown: bossAttackCooldown,
          attackDamage: bossAttackDamage,
          maxHealth: bossMaxHealth,
          bodyDamage: bossBodyDamage,
          headDamage: bossHeadDamage,
          headOffsetY: bossHeadOffsetY,
          headRadius: bossHeadRadius,
          bodyTopOffset: -150,
          bodyBottomOffset: -6,
          hurtDuration: bossHurtDuration,
          deathDuration: bossDeathDuration,
        );

  /// The game sets this so the boss can spawn its ranged projectile.
  final BossRangedFire? onRangedFire;

  // Ranged attack state.
  double _rangedCooldownTimer = 0;
  double _rangedWarnTimer = 0;
  bool _rangedWarning = false;

  /// True while the boss is telegraphing its ranged attack (before firing).
  bool get isRangedWarning => _rangedWarning;

  @override
  void update(double dt) {
    super.update(dt);

    // Only ranged-attack when alive, not hurt, and not moving (dodging or
    // climbing an obstacle).
    if (isDead || isHurt || isDodging || isAvoiding) return;

    // Range to the Hunter.
    final dx = hunter.position.x - position.x;
    final dist = dx.abs();

    if (_rangedWarning) {
      // Finish the telegraph, then fire.
      _rangedWarnTimer -= dt;
      if (_rangedWarnTimer <= 0) {
        _rangedWarning = false;
        _fireRanged();
        _rangedCooldownTimer = bossRangedCooldown;
      }
      return;
    }

    // Cooldown and only fires when the Hunter is far enough away.
    if (_rangedCooldownTimer > 0) _rangedCooldownTimer -= dt;
    if (_rangedCooldownTimer <= 0 && dist > bossRangedMinDistance) {
      _rangedWarning = true;
      _rangedWarnTimer = bossRangedWarnDuration;
    }
  }

  void _fireRanged() {
    final cb = onRangedFire;
    if (cb == null) return;
    // Launch from the boss's chest toward the Hunter.
    final origin = position + Vector2(0, -90);
    final target = hunter.position + Vector2(0, -40);
    final diff = target - origin;
    final len = diff.length;
    if (len <= 0) return;
    cb(origin, diff / len);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y);

    final alpha = isDead ? 0.45 : 1.0;

    // If ranged warning, flash a bright warning color for a clear telegraph.
    final body = Paint()
      ..color = isRangedWarning
          ? Color.fromRGBO(255, 120, 60, alpha)
          : (hitFlashTimer > 0
              ? Color.fromRGBO(255, 90, 90, alpha)
              : Color.fromRGBO(88, 110, 60, alpha));
    final dark = Paint()
      ..color = Color.fromRGBO(30, 40, 22, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    // Broad trunk / torso.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -70), width: 110, height: 130),
        const Radius.circular(24),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -70), width: 110, height: 130),
        const Radius.circular(24),
      ),
      dark,
    );

    // Weak point: a bright glowing head/eye (smaller than the body).
    final weak = Paint()
      ..color = isRangedWarning
          ? const Color(0xFFFFE066)
          : const Color(0xFFE8FF9E);
    canvas.drawCircle(const Offset(0, -150), 16, weak);
    canvas.drawCircle(const Offset(0, -150), 16, dark);

    // Legs / roots.
    canvas.drawLine(const Offset(-30, -6), const Offset(-46, 0), dark);
    canvas.drawLine(const Offset(30, -6), const Offset(46, 0), dark);

    // Heavy arms (one raised).
    canvas.drawLine(const Offset(-55, -90), const Offset(-80, -120), dark);
    canvas.drawLine(const Offset(55, -80), const Offset(85, -60), dark);

    canvas.restore();
  }
}
