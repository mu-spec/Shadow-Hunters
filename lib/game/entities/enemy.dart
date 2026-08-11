import 'dart:math' show Random;
import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'hunter.dart';

/// Shared enemy combat state machine.
///
/// All melee enemies (Skeleton, Zombie, Goblin) use this same state flow so
/// gameplay, the game's hit detection, and the HUD treat every enemy
/// uniformly. `dodging` is an optional short repositioning hop used only by
/// enemies that enable it (e.g. Goblin).
enum EnemyState { walking, attacking, hurt, dodging, dead }

/// Shared hit-zone enum used by the game's arrow-vs-enemy collision.
enum EnemyHitZone { head, body }

// Type aliases kept for backward compatibility with existing Skeleton tests.
typedef SkeletonState = EnemyState;
typedef SkeletonHitZone = EnemyHitZone;

/// Common base for every melee enemy in Shadow Hunters.
///
/// Encapsulates the combat architecture shared by all enemies: patrolling and
/// chase movement, attack timing/cooldown, head/body hit zones, damage
/// resolution, hurt/death states, and screen-space rendering helpers. Concrete
/// enemies (Skeleton, Zombie) supply their own stats and visuals so each one
/// *feels* distinct while reusing the exact same combat pipeline.
abstract class Enemy extends PositionComponent {
  Enemy({
    required Vector2 position,
    required this.hunter,
    required Vector2 size,
    required this.moveSpeed,
    required this.attackRange,
    required this.attackCooldown,
    required this.attackDamage,
    required this.maxHealth,
    required this.bodyDamage,
    required this.headDamage,
    required this.headOffsetY,
    required this.headRadius,
    required this.bodyTopOffset,
    required this.bodyBottomOffset,
    required this.hurtDuration,
    required this.deathDuration,
    this.patrolEnabled = false,
    this.battlefieldWidth = worldWidth,
    // --- Optional dodge (only enabled by e.g. Goblin) ---
    this.dodgeEnabled = false,
    this.dodgeCooldown = 3.0,
    this.dodgeDistance = 60,
    this.dodgeSpeed = 300,
    this.dodgeTelegraphDuration = 0.25,
    this.dodgeIntervalMin = 2.0,
    this.dodgeIntervalMax = 4.0,
  })  : _patrolOriginX = position.x,
        health = maxHealth,
        _dodgeIntervalTimer = _randomDodgeInterval(
          dodgeIntervalMin,
          dodgeIntervalMax,
        ),
        super(
          position: position,
          size: size,
          anchor: Anchor.bottomCenter,
        );

  final Hunter hunter;
  final bool patrolEnabled;
  final double battlefieldWidth;

  // --- Stats (supplied by the concrete enemy) ---
  final double moveSpeed;
  final double attackRange;
  final double attackCooldown;
  final double attackDamage;
  final int maxHealth;
  final int bodyDamage;
  final int headDamage;

  // --- Hit-zone geometry (in world px relative to feet/anchor) ---
  final double headOffsetY;
  final double headRadius;
  final double bodyTopOffset;
  final double bodyBottomOffset;

  final double hurtDuration;
  final double deathDuration;

  final double _patrolOriginX;
  double _patrolDirection = 1;
  late int health;
  EnemyState state = EnemyState.walking;
  double _attackTimer = 0;
  double _hurtTimer = 0;
  double _deathTimer = 0;
  double _hitFlashTimer = 0;

  // --- Dodge state (only active when [dodgeEnabled]) ---
  bool _dodging = false;
  double _dodgeCooldownTimer = 0;
  double _dodgeIntervalTimer = 0;
  double _dodgeTelegraphTimer = 0;
  double _dodgeMoveTimer = 0;
  int _dodgeDirection = 1;

  bool get isDead => state == EnemyState.dead;
  bool get isHurt => state == EnemyState.hurt;
  bool get canAttack => !isDead && _attackTimer <= 0 && !hunter.isDead;

  /// Whether this enemy can currently start a dodge: dodge enabled, alive,
  /// hunter alive, and the cooldown has elapsed.
  bool get canDodge =>
      dodgeEnabled && !isDead && !hunter.isDead && _dodgeCooldownTimer <= 0;

  /// True while the enemy is in its short repositioning hop (including the
  /// telegraph windup).
  bool get isDodging => _dodging;

  /// True only during the telegraph (windup) phase of a dodge — used by
  /// renders to signal the dodge before it fires.
  bool get isDodgeTelegraph => _dodging && _dodgeTelegraphTimer > 0;

  /// Non-zero while the enemy is flashing from a hit; used by render to tint
  /// the sprite. Kept accessible to concrete enemies' [render].
  double get hitFlashTimer => _hitFlashTimer;

  /// Pick a random interval in [min, max] for the next "occasional" dodge.
  static double _randomDodgeInterval(double min, double max) {
    if (max <= min) return min;
    return min + Random().nextDouble() * (max - min);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) {
      _deathTimer += dt;
      if (_deathTimer >= deathDuration) removeFromParent();
      return;
    }

    if (_attackTimer > 0) _attackTimer -= dt;
    if (_hitFlashTimer > 0) _hitFlashTimer -= dt;
    if (_dodgeCooldownTimer > 0) _dodgeCooldownTimer -= dt;
    if (isHurt) {
      _hurtTimer -= dt;
      if (_hurtTimer <= 0) state = EnemyState.walking;
      return;
    }

    // If a dodge is in progress, run its telegraph + movement phases and skip
    // normal chase/attack logic for the duration of the hop.
    if (_dodging) {
      _updateDodge(dt);
      return;
    }

    final dx = hunter.position.x - position.x;
    if (dx.abs() > attackRange) {
      // Level 4 patrols in a small predictable band until Hunter approaches.
      final patrolling = patrolEnabled && dx.abs() > 180;
      if (patrolling) {
        final left = (_patrolOriginX - 90).clamp(
          wallThickness + size.x / 2,
          battlefieldWidth - wallThickness - size.x / 2,
        ).toDouble();
        final right = (_patrolOriginX + 90).clamp(
          wallThickness + size.x / 2,
          battlefieldWidth - wallThickness - size.x / 2,
        ).toDouble();
        position.x += _patrolDirection * moveSpeed * 0.65 * dt;
        if (position.x <= left || position.x >= right) {
          position.x = position.x.clamp(left, right).toDouble();
          _patrolDirection = -_patrolDirection;
        }
      } else {
        position.x += dx.sign * moveSpeed * dt;
      }
      position.x = position.x
          .clamp(wallThickness + size.x / 2, battlefieldWidth - wallThickness - size.x / 2)
          .toDouble();
      state = EnemyState.walking;

      // Occasional, telegraphed short dodge while chasing (not attacking).
      if (_dodgeIntervalTimer > 0) _dodgeIntervalTimer -= dt;
      if (canDodge && _dodgeIntervalTimer <= 0) {
        _startDodge(dx);
      }
    } else {
      state = EnemyState.attacking;
      if (canAttack) _attack();
    }
  }

  /// Begins a telegraphed short dodge hop, moving away from the Hunter (a
  /// predictable direction). Telegraphs first (no movement), then quickly hops
  /// a fixed distance, always clamped to the battlefield boundaries.
  void _startDodge(double dx) {
    _dodging = true;
    state = EnemyState.dodging;
    _dodgeTelegraphTimer = dodgeTelegraphDuration;
    // Dodge away from the Hunter: if the Hunter is to the right (dx > 0),
    // dodge left (-1); if the Hunter is to the left (dx < 0), dodge right
    // (+1). Predictable every time.
    _dodgeDirection = dx >= 0 ? -1 : 1;
    _dodgeMoveTimer = dodgeDistance / (dodgeSpeed <= 0 ? 1 : dodgeSpeed);
  }

  void _updateDodge(double dt) {
    // Telegraph phase: stand still (windup) so the player can read the dodge.
    if (_dodgeTelegraphTimer > 0) {
      _dodgeTelegraphTimer -= dt;
      return;
    }

    // Movement phase: quick lateral hop, clamped to the boundaries.
    _dodgeMoveTimer -= dt;
    position.x += _dodgeDirection * dodgeSpeed * dt;
    final minX = wallThickness + size.x / 2;
    final maxX = battlefieldWidth - wallThickness - size.x / 2;
    position.x = position.x.clamp(minX, maxX).toDouble();

    if (_dodgeMoveTimer <= 0) {
      _dodging = false;
      state = EnemyState.walking;
      _dodgeCooldownTimer = dodgeCooldown;
      _dodgeIntervalTimer = _randomDodgeInterval(
        dodgeIntervalMin,
        dodgeIntervalMax,
      );
    }
  }

  void _attack() {
    _attackTimer = attackCooldown;
    hunter.takeDamage(attackDamage.toInt());
  }

  /// Returns the hit zone for an arrow point, or null outside this enemy.
  /// Head is checked first, so one arrow can never register both zones.
  EnemyHitZone? hitZoneAt(Vector2 worldPoint) {
    if (isDead) return null;
    final head = Vector2(position.x, position.y + headOffsetY);
    if (worldPoint.distanceTo(head) <= headRadius) return EnemyHitZone.head;
    final body = Rect.fromLTRB(
      position.x - size.x / 2,
      position.y + bodyTopOffset,
      position.x + size.x / 2,
      position.y + bodyBottomOffset,
    );
    return body.contains(Offset(worldPoint.x, worldPoint.y))
        ? EnemyHitZone.body
        : null;
  }

  /// Swept hit test for a fast Arrow. The head is tested first deliberately:
  /// if the segment intersects both zones, the single result is a headshot.
  EnemyHitZone? hitZoneAlongPath(Vector2 previous, Vector2 current) {
    if (isDead) return null;
    final head = Vector2(position.x, position.y + headOffsetY);
    if (_segmentIntersectsCircle(previous, current, head, headRadius)) {
      return EnemyHitZone.head;
    }
    final body = Rect.fromLTRB(
      position.x - size.x / 2,
      position.y + bodyTopOffset,
      position.x + size.x / 2,
      position.y + bodyBottomOffset,
    );
    return _segmentIntersectsRect(previous, current, body)
        ? EnemyHitZone.body
        : null;
  }

  bool _segmentIntersectsRect(Vector2 a, Vector2 b, Rect rect) {
    if (rect.contains(Offset(a.x, a.y)) || rect.contains(Offset(b.x, b.y))) {
      return true;
    }
    final corners = <Vector2>[
      Vector2(rect.left, rect.top),
      Vector2(rect.right, rect.top),
      Vector2(rect.right, rect.bottom),
      Vector2(rect.left, rect.bottom),
    ];
    for (var i = 0; i < corners.length; i++) {
      if (_segmentsIntersect(a, b, corners[i], corners[(i + 1) % corners.length])) {
        return true;
      }
    }
    return false;
  }

  bool _segmentIntersectsCircle(Vector2 a, Vector2 b, Vector2 center, double radius) {
    final segment = b - a;
    final lengthSquared = segment.length2;
    if (lengthSquared == 0) return a.distanceTo(center) <= radius;
    final projection = ((center - a).dot(segment) / lengthSquared).clamp(0.0, 1.0);
    final closest = a + segment * projection;
    return closest.distanceTo(center) <= radius;
  }

  bool _segmentsIntersect(Vector2 a, Vector2 b, Vector2 c, Vector2 d) {
    final ab = b - a;
    final ac = c - a;
    final ad = d - a;
    final cd = d - c;
    final ca = a - c;
    final cb = b - c;
    final cross1 = ab.x * ac.y - ab.y * ac.x;
    final cross2 = ab.x * ad.y - ab.y * ad.x;
    final cross3 = cd.x * ca.y - cd.y * ca.x;
    final cross4 = cd.x * cb.y - cd.y * cb.x;
    return ((cross1 >= 0 && cross2 <= 0) || (cross1 <= 0 && cross2 >= 0)) &&
        ((cross3 >= 0 && cross4 <= 0) || (cross3 <= 0 && cross4 >= 0));
  }

  int damageFor(EnemyHitZone zone) =>
      zone == EnemyHitZone.head ? headDamage : bodyDamage;

  void takeDamage(int amount) {
    if (amount <= 0 || isDead) return;
    health = (health - amount).clamp(0, maxHealth).toInt();
    if (health == 0) {
      state = EnemyState.dead;
      _deathTimer = 0;
    } else {
      state = EnemyState.hurt;
      _hurtTimer = hurtDuration;
      _hitFlashTimer = hurtDuration;
    }
  }
}
