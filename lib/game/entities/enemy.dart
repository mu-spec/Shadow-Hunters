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
    this.obstacles = const [],
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

  /// Simple static obstacles the enemy cannot walk through.
  final List<Rect> obstacles;

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

  // --- Dodge config (only enabled by e.g. Goblin) ---
  final bool dodgeEnabled;
  final double dodgeCooldown;
  final double dodgeDistance;
  final double dodgeSpeed;
  final double dodgeTelegraphDuration;
  final double dodgeIntervalMin;
  final double dodgeIntervalMax;

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

  // --- Simple obstacle avoidance state ---
  // When a chase move is blocked by an obstacle, the enemy deterministically
  // climbs up over the obstacle's top edge (the nearest accessible edge), moves
  // across to the Hunter's side, then descends back to the ground. No
  // pathfinding — just 3 simple phases.
  bool _avoiding = false;
  Rect? _avoidRect; // the obstacle currently being climbed over
  int _avoidPhase = 0; // 0 = ascend, 1 = cross, 2 = descend

  static const double _avoidClimbSpeed = 90;
  static const double _avoidCrossSpeed = 120;
  static const double _avoidDescendSpeed = 110;

  bool get isDead => state == EnemyState.dead;
  bool get isHurt => state == EnemyState.hurt;
  bool get canAttack => !isDead && _attackTimer <= 0 && !hunter.isDead;

  /// True while the enemy is climbing over an obstacle (obstacle avoidance).
  bool get isAvoiding => _avoiding;

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

  /// World-space body rect (feet at [position], extending up [size.y]).
  Rect get _bodyRect =>
      Rect.fromLTWH(position.x - size.x / 2, position.y - size.y, size.x, size.y);

  /// Returns true if the enemy's body would overlap any solid obstacle.
  bool _overlapsObstacle(Rect body) {
    for (final o in obstacles) {
      if (body.overlaps(o)) return true;
    }
    return false;
  }

  /// Blocks a lateral move: if the enemy would enter an obstacle, revert to
  /// [oldX]. Simple and deterministic — no pathfinding. Enemies stop at the
  /// obstacle edge and can still attack if the Hunter comes within range, so
  /// they are never left permanently stuck or able to pass through solid rock.
  void _blockMove(double oldX) {
    if (_overlapsObstacle(_bodyRect)) {
      position.x = oldX;
    }
  }

  /// True if the enemy's body would overlap an obstacle if its feet were at
  /// [feetX]. Exposed so specialized enemies (e.g. the boss) can re-check.
  bool overlapsObstacleAt(double feetX) => _blockedBy(feetX) != null;

  /// Returns the first obstacle whose [rect] the enemy's body (at the given
  /// feet x, current y) would overlap, or null if none.
  Rect? _blockedBy(double feetX) {
    for (final o in obstacles) {
      final body = Rect.fromLTWH(
        feetX - size.x / 2,
        position.y - size.y,
        size.x,
        size.y,
      );
      if (body.overlaps(o)) return o;
    }
    return null;
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

    // If the enemy is currently climbing over an obstacle, continue that simple
    // avoidance until it clears and can resume chasing.
    if (_avoiding) {
      _updateAvoidance(dt);
      return;
    }

    final dx = hunter.position.x - position.x;
    if (dx.abs() > attackRange) {
      // Before moving, check whether the proposed horizontal step would enter a
      // solid obstacle between us and the Hunter. If so, start a simple
      // deterministic climb-over instead of stopping permanently.
      final step = dx.sign * moveSpeed * dt;
      final proposedX = (position.x + step).clamp(
        wallThickness + size.x / 2,
        battlefieldWidth - wallThickness - size.x / 2,
      ).toDouble();
      final blocker = _blockedBy(proposedX);
      if (blocker != null && _isBetweenEnemyAndHunter(blocker)) {
        _startAvoidance(blocker);
        return;
      }

      // Level 4 patrols in a small predictable band until Hunter approaches.
      final patrolling = patrolEnabled && dx.abs() > 180;
      final oldX = position.x;
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
      // Do not walk through a solid obstacle (safety net).
      _blockMove(oldX);
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

  /// True if [rect] lies between the enemy and the Hunter (so the enemy must
  /// go around it to reach the Hunter).
  bool _isBetweenEnemyAndHunter(Rect rect) {
    final e = position.x;
    final h = hunter.position.x;
    if (e < h) return rect.right > e && rect.left < h;
    if (e > h) return rect.left < e && rect.right > h;
    return false;
  }

  /// Begins climbing over [rect]: phase 0 (ascend) raises the body above the
  /// obstacle's top, then phase 1 (cross) moves to the Hunter's side, then
  /// phase 2 (descend) returns to the ground.
  void _startAvoidance(Rect rect) {
    _avoiding = true;
    _avoidRect = rect;
    _avoidPhase = 0;
    state = EnemyState.walking;
  }

  /// Advances the simple deterministic climb-over avoidance.
  void _updateAvoidance(double dt) {
    final rect = _avoidRect;
    if (rect == null) {
      _avoiding = false;
      _avoidPhase = 0;
      return;
    }

    // Clamp to battlefield on both axes at all times.
    final minX = wallThickness + size.x / 2;
    final maxX = battlefieldWidth - wallThickness - size.x / 2;
    final maxY = groundY; // feet cannot go below the ground

    switch (_avoidPhase) {
      case 0: // Ascend until the feet reach the obstacle top (so the whole body
        // is above it and never intersects the obstacle).
        final targetY = rect.top;
        if (position.y > targetY) {
          position.y -= _avoidClimbSpeed * dt;
          if (position.y < targetY) position.y = targetY;
        } else {
          _avoidPhase = 1;
        }
        break;
      case 1: // Cross horizontally to the Hunter's side until clear.
        final dir = hunter.position.x >= position.x ? 1 : -1;
        position.x += dir * _avoidCrossSpeed * dt;
        final cleared = dir > 0
            ? position.x - size.x / 2 > rect.right
            : position.x + size.x / 2 < rect.left;
        if (cleared) _avoidPhase = 2;
        break;
      case 2: // Descend back to the ground.
        position.y += _avoidDescendSpeed * dt;
        if (position.y >= maxY) {
          position.y = maxY;
          _avoiding = false;
          _avoidPhase = 0;
          _avoidRect = null;
        }
        break;
    }

    // Clamp position within the battlefield.
    position.x = position.x.clamp(minX, maxX).toDouble();
    position.y = position.y.clamp(size.y, maxY).toDouble();
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

    // Movement phase: quick lateral hop, clamped to the boundaries. The dodge
    // must not carry the Goblin through a solid obstacle.
    _dodgeMoveTimer -= dt;
    final oldX = position.x;
    position.x += _dodgeDirection * dodgeSpeed * dt;
    final minX = wallThickness + size.x / 2;
    final maxX = battlefieldWidth - wallThickness - size.x / 2;
    position.x = position.x.clamp(minX, maxX).toDouble();
    _blockMove(oldX);

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
