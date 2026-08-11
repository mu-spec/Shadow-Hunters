import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';
import 'hunter.dart';

/// Basic melee enemy for Milestone 2A.
enum SkeletonState { walking, attacking, hurt, dead }
enum SkeletonHitZone { head, body }

class Skeleton extends PositionComponent {
  Skeleton({
    required Vector2 position,
    required this.hunter,
    this.patrolEnabled = false,
    this.battlefieldWidth = worldWidth,
  })
      : _patrolOriginX = position.x,
        super(
          position: position,
          size: Vector2(44, 72),
          anchor: Anchor.bottomCenter,
        );

  final Hunter hunter;
  final bool patrolEnabled;
  final double battlefieldWidth;
  final double _patrolOriginX;
  double _patrolDirection = 1;
  int health = skeletonMaxHealth;
  SkeletonState state = SkeletonState.walking;
  double _attackTimer = 0;
  double _hurtTimer = 0;
  double _deathTimer = 0;
  double _hitFlashTimer = 0;

  bool get isDead => state == SkeletonState.dead;
  bool get isHurt => state == SkeletonState.hurt;
  bool get canAttack => !isDead && _attackTimer <= 0 && !hunter.isDead;

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) {
      _deathTimer += dt;
      if (_deathTimer >= skeletonDeathDuration) removeFromParent();
      return;
    }

    if (_attackTimer > 0) _attackTimer -= dt;
    if (_hitFlashTimer > 0) _hitFlashTimer -= dt;
    if (isHurt) {
      _hurtTimer -= dt;
      if (_hurtTimer <= 0) state = SkeletonState.walking;
      return;
    }

    final dx = hunter.position.x - position.x;
    if (dx.abs() > skeletonAttackRange) {
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
        position.x += _patrolDirection * skeletonSpeed * 0.65 * dt;
        if (position.x <= left || position.x >= right) {
          position.x = position.x.clamp(left, right).toDouble();
          _patrolDirection = -_patrolDirection;
        }
      } else {
        position.x += dx.sign * skeletonSpeed * dt;
      }
      position.x = position.x
          .clamp(wallThickness + size.x / 2, battlefieldWidth - wallThickness - size.x / 2)
          .toDouble();
      state = SkeletonState.walking;
    } else {
      state = SkeletonState.attacking;
      if (canAttack) _attack();
    }
  }

  void _attack() {
    _attackTimer = skeletonAttackCooldown;
    hunter.takeDamage(skeletonAttackDamage.toInt());
  }

  /// Returns the hit zone for an arrow point, or null outside the Skeleton.
  /// Head is checked first, so one arrow can never register both zones.
  SkeletonHitZone? hitZoneAt(Vector2 worldPoint) {
    if (isDead) return null;
    final head = Vector2(position.x, position.y - 58);
    if (worldPoint.distanceTo(head) <= 11) return SkeletonHitZone.head;
    final body = Rect.fromLTRB(
      position.x - size.x / 2,
      position.y - 49,
      position.x + size.x / 2,
      position.y - 4,
    );
    return body.contains(Offset(worldPoint.x, worldPoint.y))
        ? SkeletonHitZone.body
        : null;
  }

  /// Swept hit test for a fast Arrow. The head is tested first deliberately:
  /// if the segment intersects both zones, the single result is a headshot.
  SkeletonHitZone? hitZoneAlongPath(Vector2 previous, Vector2 current) {
    if (isDead) return null;
    final head = Vector2(position.x, position.y - 58);
    if (_segmentIntersectsCircle(previous, current, head, 11)) {
      return SkeletonHitZone.head;
    }
    final body = Rect.fromLTRB(
      position.x - size.x / 2,
      position.y - 49,
      position.x + size.x / 2,
      position.y - 4,
    );
    return _segmentIntersectsRect(previous, current, body)
        ? SkeletonHitZone.body
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

  int damageFor(SkeletonHitZone zone) =>
      zone == SkeletonHitZone.head ? skeletonHeadDamage : skeletonBodyDamage;

  void takeDamage(int amount) {
    if (amount <= 0 || isDead) return;
    health = (health - amount).clamp(0, skeletonMaxHealth).toInt();
    if (health == 0) {
      state = SkeletonState.dead;
      _deathTimer = 0;
    } else {
      state = SkeletonState.hurt;
      _hurtTimer = skeletonHurtDuration;
      _hitFlashTimer = skeletonHurtDuration;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    final alpha = isDead ? 0.45 : 1.0;
    final bone = Paint()
      ..color = _hitFlashTimer > 0
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
