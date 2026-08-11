import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/enemy.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/entities/zombie.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  Zombie makeZombie(Hunter hunter) =>
      Zombie(position: Vector2(1200, groundY), hunter: hunter);

  test('Zombie is slower and tougher than a Skeleton', () {
    // Statically distinct tuning: high health, low speed, slow attack.
    expect(zombieMaxHealth, greaterThan(skeletonMaxHealth));
    expect(zombieSpeed, lessThan(skeletonSpeed));
    expect(zombieAttackCooldown, greaterThan(skeletonAttackCooldown));
    expect(zombieAttackDamage, greaterThan(skeletonAttackDamage));
  });

  test('Zombie is a larger target (bigger body) than a Skeleton', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final zombie = makeZombie(hunter);
    expect(zombie.size.x, greaterThan(44)); // Skeleton width
    expect(zombie.size.y, greaterThan(72)); // Skeleton height
  });

  test('Zombie has high health and headshots are supported', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final zombie = makeZombie(hunter);

    // High base health.
    expect(zombie.health, zombieMaxHealth);
    expect(zombie.health, greaterThan(skeletonMaxHealth));

    // A body shot deals less than a headshot.
    expect(zombie.damageFor(EnemyHitZone.body), zombieBodyDamage);
    expect(zombie.damageFor(EnemyHitZone.head), zombieHeadDamage);
    expect(zombie.damageFor(EnemyHitZone.head),
        greaterThan(zombie.damageFor(EnemyHitZone.body)));

    // Headshot zone is recognized.
    final headY = zombie.position.y - 66;
    expect(
      zombie.hitZoneAlongPath(
        Vector2(zombie.position.x - 100, headY),
        Vector2(zombie.position.x + 100, headY),
      ),
      EnemyHitZone.head,
    );
  });

  test('Zombie takes many hits to kill (tanky)', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final zombie = makeZombie(hunter);

    // It should require multiple body hits vs a single kill on a Skeleton.
    final hitsToKill = (zombieMaxHealth / zombieBodyDamage).ceil();
    expect(hitsToKill, greaterThan(2));

    var hits = 0;
    while (!zombie.isDead && hits < 100) {
      zombie.takeDamage(zombieBodyDamage);
      hits++;
    }
    expect(zombie.isDead, isTrue);
    expect(hits, hitsToKill);
  });

  test('Zombie moves slowly toward the Hunter', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final zombie = Zombie(
      position: Vector2(1200, groundY),
      hunter: hunter,
    );
    final origin = zombie.position.x;
    zombie.update(1);
    // Slow move speed => travelled less than the Skeleton would in 1s (72px).
    expect(zombie.position.x, lessThan(origin));
    expect(origin - zombie.position.x, lessThan(72));
  });

  test('Zombie attacks strongly but slowly (cooldown gates damage)', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final zombie = makeZombie(hunter)
      ..position.x = hunter.position.x + zombieAttackRange - 1;
    final healthBefore = hunter.health;

    zombie.update(0.01); // enter attack range, first attack fires
    final afterFirst = hunter.health;
    expect(healthBefore - afterFirst, zombieAttackDamage);

    // Second update within the cooldown does no additional damage.
    zombie.update(0.5);
    expect(hunter.health, afterFirst);

    // After the cooldown elapses, it can attack again.
    zombie.update(zombieAttackCooldown);
    expect(hunter.health, lessThan(afterFirst));
  });
}
