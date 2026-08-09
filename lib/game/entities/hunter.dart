import 'dart:math' show cos, pi, sin;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextDirection, TextPainter, TextSpan, TextStyle;

import '../aim/aim_state.dart';
import '../physics/projectile.dart';
import '../world/constants.dart';

/// Movement state of the hunter.
enum HunterState { idle, moving }

/// The prototype player character.
///
/// Handles movement (left/right), facing direction, boundary clamping and
/// staying grounded. Movement is applied in [update] using `dt`, so it is
/// frame-rate independent and resilient to pause/resume (each update reads the
/// current move direction fresh).
///
/// Also renders the bow, rotating it to the shared [aim] direction, and draws a
/// projectile trajectory preview while aiming.
///
/// The hunter is anchored at its feet ([Anchor.bottomCenter]) so `position.y`
/// is the ground top and it never falls through the ground.
class Hunter extends PositionComponent {
  Hunter({required super.position, required this.aim})
      : super(
          size: Vector2(48, 76),
          anchor: Anchor.bottomCenter,
        );

  /// Shared aim state updated by the aim pad.
  final AimState aim;

  /// How many health points the hunter has.
  int health = hunterMaxHealth;

  /// Current movement direction: -1 = left, 0 = idle, +1 = right.
  int moveDirection = 0;

  /// Facing: -1 = facing left, +1 = facing right.
  double facing = 1;

  HunterState get state => moveDirection == 0 ? HunterState.idle : HunterState.moving;

  /// World-space rectangle covering the FULL visible Hunter body (head, torso,
  /// arms/bow, waist, legs), with a small forgiving touch margin for mobile.
  ///
  /// The Hunter is anchored at its feet ([Anchor.bottomCenter]), so
  /// [position] is the feet. The body spans `height` up from the feet; the rect
  /// is expanded by [aimTouchMargin] on all sides.
  Rect get aimTouchRect {
    final halfW = size.x / 2 + aimTouchMargin;
    final top = position.y - size.y - aimTouchMargin;
    final bottom = position.y + aimTouchMargin;
    return Rect.fromLTRB(
      position.x - halfW,
      top,
      position.x + halfW,
      bottom,
    );
  }

  /// Forgiving touch margin around the body for comfortable mobile aiming.
  static const double aimTouchMargin = 10;
  ///
  /// The bow pivot is drawn at local `(0, -42)` from the feet; the string/nock
  /// sits 10 units back (opposite the firing direction) from the pivot, which
  /// is exactly where the drawn bowstring/arrow-nock is in [render].
  Vector2 bowReleasePositionFor(double angle) =>
      position + Vector2(0, -42) - Vector2(cos(angle), -sin(angle)) * 10;

  /// How far the bowstring is pulled back (draw tension) while aiming, in world
  /// units. Derived from the current pull power (0..1) so greater pull visually
  /// draws the string back farther. 0 when not aiming.
  double get bowDraw =>
      (aim.active ? aim.power * bowMaxDraw : 0.0);

  /// World-space position of the fired arrow's CENTER at release: its rear nock
  /// sits at the drawn-string position and the arrow extends forward.
  ///
  /// When aiming, the string (and nock) are pulled back by [bowDraw], so the
  /// launch origin accounts for the draw so the released arrow is continuous
  /// with the nocked arrow. This is the single authoritative launch origin
  /// shared by the trajectory preview and the actual Arrow.
  Vector2 arrowLaunchCenterFor(double angle) {
    final dir = Vector2(cos(angle), -sin(angle));
    // String/nock pulls back by bowDraw from the resting release point.
    final nock = bowReleasePositionFor(angle) - dir * bowDraw;
    return nock + dir * (arrowLength / 2);
  }

  /// Resets the Hunter to its original state: spawn position, full health,
  /// idle, default facing, and zero movement input.
  void reset(Vector2 spawn) {
    position.setFrom(spawn);
    health = hunterMaxHealth;
    moveDirection = 0;
    facing = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Apply horizontal movement, scaled by dt (frame-rate independent).
    if (moveDirection != 0) {
      position.x += moveDirection * hunterSpeed * dt;
    }

    // Clamp so the hunter cannot leave the battlefield.
    // clamp on num returns num; convert back to double for the position.
    position.x = position.x
        .clamp(hunterBoundaryLeft, hunterBoundaryRight)
        .toDouble();

    // Stay anchored on the ground (feet at groundY).
    position.y = groundY;

    // Face the direction of movement (defaults to facing right).
    if (moveDirection != 0) {
      facing = moveDirection.toDouble();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Local origin is the feet centre (Anchor.bottomCenter). +x is right,
    // -y is up.
    final f = facing; // multiplier for left/right facing

    // --- Legs ---
    final legPaint = Paint()..color = const Color(0xFF8A5A2E);
    canvas.drawLine(Offset(0, -4), Offset(-8 * f, -26), legPaint..strokeWidth = 6);
    canvas.drawLine(Offset(0, -4), Offset(8 * f, -26), legPaint..strokeWidth = 6);

    // --- Torso ---
    final bodyPaint = Paint()..color = const Color(0xFFB07A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -40), width: 26, height: 30),
        const Radius.circular(8),
      ),
      bodyPaint,
    );

    // --- Hood / head ---
    final headPaint = Paint()..color = const Color(0xFFD8A45C);
    canvas.drawCircle(Offset(0, -60), 12, headPaint);
    // Eye (offset by facing).
    canvas.drawCircle(Offset(4 * f, -60), 2.5, Paint()..color = const Color(0xFF1B2733));

    // --- Arms ---
    final armPaint = Paint()..color = const Color(0xFF8A5A2E);
    canvas.drawLine(Offset(0, -40), Offset(12 * f, -30), armPaint..strokeWidth = 5);
    canvas.drawLine(Offset(0, -40), Offset(-10 * f, -28), armPaint..strokeWidth = 5);

    // --- Bow (rotates to aim) ---
    _renderBow(canvas, f);

    // --- Health bar above the head ---
    const barWidth = 40.0;
    const barHeight = 6.0;
    final ratio = (health / hunterMaxHealth).clamp(0.0, 1.0).toDouble();
    final barY = -78.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-barWidth / 2, barY, barWidth, barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3A4754),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-barWidth / 2, barY, barWidth * ratio, barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF7FD44E),
    );

    // --- State label ---
    final painter = TextPainter(
      text: TextSpan(
        text: state == HunterState.moving ? 'MOVING' : 'IDLE',
        style: const TextStyle(
          color: Color(0xFFB8C6D2),
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -94));
  }

  /// Renders the bow at the hunter's hand, rotating it to the aim direction.
  ///
  /// [f] is the facing multiplier. The bow is drawn pointing along +x and then
  /// rotated by `-angle` so it points along the aim direction (up = -y).
  void _renderBow(Canvas canvas, double f) {
    // When idle (not aiming) point the bow forward along the facing.
    // Use 0.0 (not 0) so the ternary yields double, not num.
    final angle = aim.active ? aim.worldAngle : (f > 0 ? 0.0 : pi);
    final pivot = Offset(0, -42); // held around the torso

    // String rest position is x=-10 (in the bow's rotated frame). While aiming,
    // the string (and nock) pull back by bowDraw for realistic draw tension.
    final restStringX = -10.0;
    final stringX = aim.active ? restStringX - bowDraw : restStringX;

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-angle);

    // Bow arc (curved back bulging to the -x side). More tension (deeper draw)
    // bends the arc slightly more.
    final bowPaint = Paint()
      ..color = const Color(0xFF8A6B3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final bend = aim.active ? 2.0 + bowDraw * 0.25 : 2.0;
    canvas.drawArc(
      Rect.fromLTWH(-10 - bend, -16, bowLength + bend, 32),
      -pi / 2,
      pi,
      false,
      bowPaint,
    );

    // Bowstring (from one bow tip to the other, dipping to the drawn nock).
    final stringPaint = Paint()
      ..color = const Color(0xFFD8C9A8)
      ..strokeWidth = 2;
    // Bow tips are roughly at the arc ends.
    final tipY = 16.0;
    canvas.drawLine(
        Offset(restStringX - bend, -tipY), Offset(stringX, 0), stringPaint);
    canvas.drawLine(
        Offset(restStringX - bend, tipY), Offset(stringX, 0), stringPaint);

    // Temporary nocked Arrow while aiming: attached to the string, tip pointing
    // along the firing direction (+x in this rotated frame).
    final nocked = aim.active;
    final arrowLen = nocked ? arrowLength : arrowLength * 0.6;
    final arrowStartX = stringX; // nock at the drawn string
    final arrowPaint = Paint()
      ..color = const Color(0xFFB8A06A)
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(arrowStartX, 0), Offset(arrowStartX + arrowLen, 0), arrowPaint);
    // Arrowhead.
    final headPaint = Paint()..color = const Color(0xFFD8E0E8);
    final headX = arrowStartX + arrowLen;
    canvas.drawPath(
      Path()
        ..moveTo(headX, -5)
        ..lineTo(headX + 10, 0)
        ..lineTo(headX, 5)
        ..close(),
      headPaint,
    );
    // Fletching at the nock.
    final fletchPaint = Paint()..color = const Color(0xFF7FD44E);
    canvas.drawPath(
      Path()
        ..moveTo(arrowStartX, 0)
        ..lineTo(arrowStartX - 7, -5)
        ..lineTo(arrowStartX - 7, 5)
        ..close(),
      fletchPaint,
    );

    canvas.restore();

    // Trajectory preview only once the minimum pull threshold is reached.
    if (aim.active && aim.canFire) {
      _renderTrajectory(canvas, angle);
    }
  }

  /// Draws dots along the projectile path for the current aim + power.
  ///
  /// Uses the same [Projectile] math and the SAME launch origin as the flying
  /// Arrow (see [arrowLaunchCenterFor]), so the preview aligns exactly with the
  /// released Arrow with no positional jump from the Bow.
  void _renderTrajectory(Canvas canvas, double angle) {
    final dir = Vector2(cos(angle), -sin(angle));
    final speed = aim.speed;
    final p0 = arrowLaunchCenterFor(angle);
    final vel = dir * speed;

    final dot = Paint()..color = const Color(0xCCFFFFFF);
    for (double t = 0; t < 2.0; t += 0.07) {
      final p = Projectile.position(p0, vel, arrowGravity, t);
      // Stop once the preview drops to (or below) the ground line.
      if (p.y >= 0) break;
      canvas.drawCircle(Offset(p.x, p.y), 3, dot);
    }
  }
}
