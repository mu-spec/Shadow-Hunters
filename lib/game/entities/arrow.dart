import 'dart:math' show atan2;
import 'dart:ui';

import 'package:flame/components.dart';

import '../world/constants.dart';

/// A fired arrow with projectile physics.
///
/// States:
/// - **flying**: velocity has gravity applied each frame; position integrates;
///   rotation follows the velocity direction; stops on ground/world collision.
/// - **stuck**: after ground impact the arrow briefly sticks into the ground,
///   then is removed. A limited total lifetime cleans up any arrow that never
///   hits (e.g. fired high and clipped a wall).
class Arrow extends PositionComponent {
  Arrow({required super.position, required Vector2 velocity, this.worldWidth = 2560, this.worldHeight = 720})
      : _velocity = velocity.clone(),
        // Anchor at CENTER so `position` is the visual center of the arrow and
        // rotation spins around the shaft center (not a corner). This makes the
        // launched arrow's rear/nock land exactly on the bow release point.
        super(anchor: Anchor.center);

  /// How long an arrow stays stuck in the ground before disappearing.
  static const double stickDuration = 2.5;

  /// Absolute maximum lifetime in flight (safety cleanup).
  static const double maxLife = 6.0;

  final double worldWidth;
  final double worldHeight;
  final Vector2 _velocity;

  /// Current rotation of the arrow (radians), following the velocity vector.
  /// Named `rotation` (not `angle`) so it doesn't shadow PositionComponent.angle.
  double rotation = 0;

  bool _flying = true;
  double _life = 0;
  double _stickTime = 0;

  bool get flying => _flying;

  @override
  void update(double dt) {
    super.update(dt);
    if (_flying) {
      _step(dt);
    } else {
      // Stuck: count down to cleanup.
      _stickTime += dt;
      if (_stickTime >= stickDuration) removeFromParent();
    }
  }

  void _step(double dt) {
    _life += dt;

    // Gravity (positive down).
    _velocity.y += arrowGravity * dt;

    // Integrate position.
    position.add(_velocity * dt);

    // Rotation follows the velocity vector (0 = right, + = down).
    rotation = atan2(_velocity.y, _velocity.x);

    // --- World collisions ---
    // Ground: stick into the ground.
    if (position.y >= worldHeight - groundHeight) {
      position.y = worldHeight - groundHeight;
      _flying = false;
      _stickTime = 0;
      return;
    }
    // Left / right walls.
    if (position.x <= wallThickness) {
      position.x = wallThickness;
      _flying = false;
      return;
    }
    if (position.x >= worldWidth - wallThickness) {
      position.x = worldWidth - wallThickness;
      _flying = false;
      return;
    }
    // Top wall: stop it from leaving the world (keeps cleanup simple).
    if (position.y <= wallThickness) {
      position.y = wallThickness;
      _flying = false;
      return;
    }

    // Limited lifetime cleanup.
    if (_life >= maxLife) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    canvas.rotate(rotation);

    // Shaft (points along +x before rotation).
    final shaftPaint = Paint()
      ..color = const Color(0xFFB8A06A)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(-arrowLength / 2, 0), Offset(arrowLength / 2, 0), shaftPaint);

    // Arrowhead.
    final head = Path()
      ..moveTo(arrowLength / 2, -5)
      ..lineTo(arrowLength / 2 + 9, 0)
      ..lineTo(arrowLength / 2, 5)
      ..close();
    canvas.drawPath(head, Paint()..color = const Color(0xFFD8E0E8));

    // Fletching (tail).
    final fletch = Path()
      ..moveTo(-arrowLength / 2, 0)
      ..lineTo(-arrowLength / 2 - 7, -5)
      ..lineTo(-arrowLength / 2 - 7, 5)
      ..close();
    canvas.drawPath(fletch, Paint()..color = const Color(0xFF7FD44E));

    canvas.restore();
  }
}
