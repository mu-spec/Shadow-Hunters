import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/entities/arrow.dart';
import 'package:shadow_hunters/game/world/constants.dart';

void main() {
  test('Arrow defaults to no sprite (procedural fallback)', () {
    final arrow = Arrow(
      position: Vector2(200, groundY - 200),
      velocity: Vector2(300, -300),
    );
    expect(arrow.sprite, isNull);
    expect(arrow.spriteHeight, 0);
  });

  test('Arrow applies gravity, follows velocity rotation, and curves', () {
    final arrow = Arrow(
      position: Vector2(200, groundY - 200),
      velocity: Vector2(300, -300),
    );
    final before = arrow.position.clone();
    arrow.update(0.1);
    expect(arrow.position.x, greaterThan(before.x));
    expect(arrow.position.y, lessThan(before.y));
    expect(arrow.rotation, isNot(0));
  });

  test('Arrow stops at ground and world boundaries', () {
    final groundArrow = Arrow(
      position: Vector2(200, groundY - 1),
      velocity: Vector2(0, 100),
    );
    groundArrow.update(0.1);
    expect(groundArrow.flying, isFalse);
    expect(groundArrow.position.y, groundY);

    final wallArrow = Arrow(
      position: Vector2(wallThickness + 1, groundY - 100),
      velocity: Vector2(-100, 0),
    );
    wallArrow.update(0.1);
    expect(wallArrow.flying, isFalse);
    expect(wallArrow.position.x, wallThickness);
  });

  test('Arrow weak and strong velocities produce different ranges', () {
    final weak = Arrow(
      position: Vector2(200, groundY - 100),
      velocity: Vector2(500, 0),
    );
    final strong = Arrow(
      position: Vector2(200, groundY - 100),
      velocity: Vector2(1000, 0),
    );
    for (var i = 0; i < 10; i++) {
      weak.update(0.05);
      strong.update(0.05);
    }
    expect(strong.position.x, greaterThan(weak.position.x));
  });
}
