import 'dart:math' show atan2;
import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart' as world;

/// The Forest Guardian's simple ranged projectile.
///
/// Travels in a straight line at [world.bossRangedSpeed]. It damages the Hunter
/// on contact and is removed when it leaves the battlefield or hits an
/// obstacle. There is only this one ranged attack (no variants), and it is
/// telegraphed by the boss before firing.
class BossProjectile extends PositionComponent {
  BossProjectile({
    required super.position,
    required Vector2 direction,
    this.worldWidth = world.worldWidth,
    this.worldHeight = world.worldHeight,
  })  : _dir = direction.clone(),
        super(anchor: Anchor.center);

  static const double radius = 14;

  final double worldWidth;
  final double worldHeight;
  final Vector2 _dir;

  /// Radius within which it damages the Hunter (world px).
  static const double hitRadius = 22;

  bool _spent = false;

  /// True once the projectile has been consumed (hit or left the world).
  bool get spent => _spent;

  /// Unit direction of travel.
  Vector2 get direction => _dir;

  double get rotation => atan2(_dir.y, _dir.x);

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;
    position.add(_dir * world.bossRangedSpeed * dt);

    // Leave the battlefield.
    if (position.x < world.wallThickness ||
        position.x > worldWidth - world.wallThickness ||
        position.y < world.wallThickness ||
        position.y > worldHeight - world.groundHeight) {
      _spent = true;
      removeFromParent();
    }
  }

  /// Mark the projectile as consumed (e.g. after hitting the Hunter).
  void consume() {
    _spent = true;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.rotate(rotation);
    // A glowing energy orb with a small tail.
    final glow = Paint()..color = const Color(0x99FFE066);
    canvas.drawCircle(Offset.zero, 20, glow);
    final core = Paint()..color = const Color(0xFFFFE066);
    canvas.drawCircle(Offset.zero, radius, core);
    final inner = Paint()..color = const Color(0xFFAAE066);
    canvas.drawCircle(Offset.zero, 6, inner);
    canvas.restore();
  }
}
