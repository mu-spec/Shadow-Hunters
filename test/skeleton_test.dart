import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/entities/skeleton.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  Skeleton makeSkeleton(Hunter hunter) =>
      Skeleton(position: Vector2(500, groundY), hunter: hunter);

  test('patrolling Skeleton moves predictably within its patrol band', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = Skeleton(
      position: Vector2(1200, groundY),
      hunter: hunter,
      patrolEnabled: true,
    );
    final origin = skeleton.position.x;
    skeleton.update(1);
    expect(skeleton.position.x, greaterThan(origin));
    expect(skeleton.position.x, lessThanOrEqualTo(origin + 90));
  });

  test('skeleton walks toward Hunter and stops in attack range', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    skeleton.update(1);
    expect(skeleton.position.x, lessThan(500));

    skeleton.position.x = hunter.position.x + skeletonAttackRange - 1;
    skeleton.update(0.01);
    expect(skeleton.position.x, closeTo(hunter.position.x + skeletonAttackRange - 1, 0.01));
    expect(skeleton.state, SkeletonState.attacking);
  });

  test('attack cooldown limits damage and Hunter health clamps at zero', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter)
      ..position.x = hunter.position.x + skeletonAttackRange - 1;
    skeleton.update(0.01);
    final afterFirst = hunter.health;
    skeleton.update(0.01);
    expect(hunter.health, afterFirst);
    hunter.takeDamage(10000);
    expect(hunter.health, 0);
    expect(hunter.isDead, isTrue);
  });

  test('swept path catches a fast Arrow crossing the head', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    final y = skeleton.position.y - 58;
    expect(
      skeleton.hitZoneAlongPath(
        Vector2(skeleton.position.x - 100, y),
        Vector2(skeleton.position.x + 100, y),
      ),
      SkeletonHitZone.head,
    );
  });

  test('swept path catches a fast Arrow crossing the body', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    final y = skeleton.position.y - 30;
    expect(
      skeleton.hitZoneAlongPath(
        Vector2(skeleton.position.x - 100, y),
        Vector2(skeleton.position.x + 100, y),
      ),
      SkeletonHitZone.body,
    );
  });

  test('head has priority and one swept path returns one zone', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    final x = skeleton.position.x;
    expect(
      skeleton.hitZoneAlongPath(
        Vector2(x, skeleton.position.y - 70),
        Vector2(x, skeleton.position.y - 2),
      ),
      SkeletonHitZone.head,
    );
  });

  test('dead Skeleton cannot register head or body hits', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    skeleton.takeDamage(skeletonMaxHealth);
    expect(
      skeleton.hitZoneAt(Vector2(skeleton.position.x, skeleton.position.y - 58)),
      isNull,
    );
    expect(
      skeleton.hitZoneAlongPath(
        Vector2(skeleton.position.x - 100, skeleton.position.y - 30),
        Vector2(skeleton.position.x + 100, skeleton.position.y - 30),
      ),
      isNull,
    );
  });

  test('head and body are separate hit zones with one damage result', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    expect(
      skeleton.hitZoneAt(Vector2(skeleton.position.x, skeleton.position.y - 58)),
      SkeletonHitZone.head,
    );
    expect(
      skeleton.hitZoneAt(Vector2(skeleton.position.x, skeleton.position.y - 30)),
      SkeletonHitZone.body,
    );
    expect(skeleton.damageFor(SkeletonHitZone.head), greaterThan(skeletonBodyDamage));
  });

  test('body damage reduces health and enters hurt state', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    skeleton.takeDamage(skeletonBodyDamage);
    expect(skeleton.health, skeletonMaxHealth - skeletonBodyDamage);
    expect(skeleton.state, SkeletonState.hurt);
  });

  test('repeated combat damage reaches death exactly once', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    for (var i = 0; i < skeletonMaxHealth ~/ skeletonBodyDamage; i++) {
      skeleton.takeDamage(skeletonBodyDamage);
      if (!skeleton.isDead) skeleton.update(skeletonHurtDuration + 0.01);
    }
    expect(skeleton.health, 0);
    expect(skeleton.state, SkeletonState.dead);
    skeleton.takeDamage(skeletonBodyDamage);
    expect(skeleton.health, 0);
  });

  test('hurt state returns to walking behavior after recovery', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    skeleton.takeDamage(1);
    expect(skeleton.state, SkeletonState.hurt);
    skeleton.update(skeletonHurtDuration + 0.01);
    expect(skeleton.state, SkeletonState.walking);
    final before = skeleton.position.x;
    skeleton.update(0.1);
    expect(skeleton.position.x, lessThan(before));
  });

  test('dead Skeleton cannot move, attack, or receive damage', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter)
      ..position.x = hunter.position.x + skeletonAttackRange - 1;
    skeleton.takeDamage(skeletonMaxHealth);
    final positionAtDeath = skeleton.position.clone();
    final hunterHealthAtDeath = hunter.health;

    skeleton.update(2.0);
    expect(skeleton.state, SkeletonState.dead);
    expect(skeleton.position.x, closeTo(positionAtDeath.x, 0.001));
    expect(skeleton.position.y, closeTo(positionAtDeath.y, 0.001));
    expect(hunter.health, hunterHealthAtDeath);

    skeleton.takeDamage(1000);
    expect(skeleton.health, 0);
  });

  test('skeleton hurt and death states are distinct', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final skeleton = makeSkeleton(hunter);
    skeleton.takeDamage(1);
    expect(skeleton.state, SkeletonState.hurt);
    skeleton.takeDamage(skeletonMaxHealth);
    expect(skeleton.state, SkeletonState.dead);
    expect(skeleton.health, 0);
    skeleton.takeDamage(10);
    expect(skeleton.health, 0);
  });
}
