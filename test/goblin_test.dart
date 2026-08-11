import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/enemy.dart';
import 'package:shadow_hunters/game/entities/goblin.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  Goblin makeGoblin(Hunter hunter) =>
      Goblin(position: Vector2(1200, groundY), hunter: hunter);

  test('Goblin is faster and frailer than a Skeleton', () {
    expect(goblinSpeed, greaterThan(skeletonSpeed));
    expect(goblinMaxHealth, lessThan(skeletonMaxHealth));
    expect(goblinAttackCooldown, lessThan(skeletonAttackCooldown));
  });

  test('Goblin is a smaller target (smaller body) than a Skeleton', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final goblin = makeGoblin(hunter);
    expect(goblin.size.x, lessThan(44)); // Skeleton width
    expect(goblin.size.y, lessThan(72)); // Skeleton height
  });

  test('Goblin supports headshots (head deals more than body)', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final goblin = makeGoblin(hunter);

    expect(goblin.damageFor(EnemyHitZone.head),
        greaterThan(goblin.damageFor(EnemyHitZone.body)));

    final headY = goblin.position.y - 44;
    expect(
      goblin.hitZoneAlongPath(
        Vector2(goblin.position.x - 100, headY),
        Vector2(goblin.position.x + 100, headY),
      ),
      EnemyHitZone.head,
    );
  });

  test('Goblin moves quickly toward the Hunter', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final goblin = Goblin(position: Vector2(1200, groundY), hunter: hunter);
    final origin = goblin.position.x;
    goblin.update(1);
    // Fast move speed => covers more ground than the Skeleton (72px in 1s).
    expect(origin - goblin.position.x, greaterThan(72));
  });

  test('Goblin attacks fast (cooldown gates frequent damage)', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final goblin = makeGoblin(hunter)
      ..position.x = hunter.position.x + goblinAttackRange - 1;
    final healthBefore = hunter.health;

    goblin.update(0.01); // enter range, attack fires
    expect(healthBefore - hunter.health, goblinAttackDamage);

    // A short wait (less than the longer skeleton cooldown) already allows
    // another attack because the goblin's cooldown is shorter.
    goblin.update(goblinAttackCooldown);
    expect(hunter.health, lessThan(healthBefore - goblinAttackDamage));
  });

  test('Goblin dodge is telegraphed, then hops, then respects cooldown',
      () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    final goblin = makeGoblin(hunter);
    // Force the next dodge interval to expire immediately (max interval elapses).
    goblin.update(goblinDodgeIntervalMax + 0.1);

    // Telegraph phase: no movement yet, but flagged as telegraphing.
    expect(goblin.isDodging, isTrue);
    expect(goblin.isDodgeTelegraph, isTrue);
    final telegraphStart = goblin.position.x;
    goblin.update(goblinDodgeTelegraphDuration / 2);
    expect(goblin.isDodgeTelegraph, isTrue);
    expect(goblin.position.x, closeTo(telegraphStart, 0.001));

    // A small step exits the telegraph and begins the hop, moving a short way.
    goblin.update(goblinDodgeTelegraphDuration / 2);
    expect(goblin.isDodgeTelegraph, isFalse);
    expect(goblin.isDodging, isTrue);
    expect((goblin.position.x - telegraphStart).abs(), lessThan(goblinDodgeDistance));

    // Let the hop finish.
    goblin.update(goblinDodgeDistance / goblinDodgeSpeed + 0.1);
    expect(goblin.isDodging, isFalse);

    // Right after the hop, the cooldown blocks an immediate re-dodge...
    goblin.update(0.1);
    expect(goblin.canDodge, isFalse, reason: 'cooldown should block an immediate dodge');

    // ...and once the cooldown elapses it can dodge again.
    goblin.update(goblinDodgeCooldown);
    expect(goblin.canDodge, isTrue, reason: 'cooldown elapsed so dodge is available');
  });

  test('Goblin dodge stays within the battlefield boundaries', () {
    final hunter = Hunter(position: Vector2(220, groundY), aim: AimState());
    // Place near the left wall, facing away would push further right; ensure
    // the hop never leaves [wallThickness, battlefieldWidth - wallThickness].
    final goblin = Goblin(
      position: Vector2(wallThickness + 20, groundY),
      hunter: hunter,
    );
    final minX = wallThickness + goblin.size.x / 2;
    final maxX = worldWidth - wallThickness - goblin.size.x / 2;
    for (var i = 0; i < 200; i++) {
      goblin.update(1 / 60);
      expect(goblin.position.x, greaterThanOrEqualTo(minX - 0.001));
      expect(goblin.position.x, lessThanOrEqualTo(maxX + 0.001));
    }
  });
}
