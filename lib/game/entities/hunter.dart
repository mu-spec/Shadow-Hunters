import 'dart:math' show cos, pi, sin;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextDirection, TextPainter, TextSpan, TextStyle;

import '../aim/aim_state.dart';
import '../physics/projectile.dart';
import '../world/constants.dart';
import 'hunter_visual.dart';

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
  Hunter({
    required super.position,
    required this.aim,
    this.battlefieldWidth = worldWidth,
    this.battlefieldHeight = worldHeight,
    this.obstacles = const [],
    this.visual,
  })
      : super(
          size: Vector2(48, 76),
          anchor: Anchor.bottomCenter,
        );

  /// Shared aim state updated by the aim pad.
  final AimState aim;
  final double battlefieldWidth;
  final double battlefieldHeight;

  /// Simple static obstacles the Hunter cannot walk through.
  final List<Rect> obstacles;

  /// Optional Phase 9A artwork. When null (or [useArtwork] is false), the
  /// original procedural placeholder rendering is used as the fallback path.
  HunterVisual? visual;

  /// Master switch to restore the procedural placeholder visuals. Kept for a
  /// simple development/fallback path if the Phase 9 prototype is reverted.
  bool useArtwork = true;

  /// How many health points the hunter has.
  int health = hunterMaxHealth;

  /// Current movement direction: -1 = left, 0 = idle, +1 = right.
  int moveDirection = 0;

  /// Facing: -1 = facing left, +1 = facing right.
  double facing = 1;

  HunterState get state => moveDirection == 0 ? HunterState.idle : HunterState.moving;

  /// World-space touch bounds covering the corrected visible Hunter body with
  /// a small mobile-friendly margin.
  Rect get aimTouchRect => Rect.fromLTRB(
        position.x - size.x / 2 - aimTouchMargin,
        position.y - size.y - aimTouchMargin,
        position.x + size.x / 2 + aimTouchMargin,
        position.y + aimTouchMargin,
      );

  /// The Hunter's REAL gameplay collision bounds in world space (its body, feet
  /// at [position], extending up [size.y]). This is the single authoritative
  /// hitbox shared by obstacle collision and boss-projectile collision, so a
  /// projectile uses exactly what the game world considers "the Hunter".
  Rect get collisionRect => Rect.fromLTWH(
        position.x - size.x / 2,
        position.y - size.y,
        size.x,
        size.y,
      );

  static const double aimTouchMargin = 10;

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
  /// World-space position of the visible bow string/nock for this angle.
  /// This is the single release point shared by the drawn arrow, preview, and
  /// projectile. [draw] is optional so release snapshots can pass an immutable
  /// value after aim state has been reset.
  Vector2 bowStringReleasePositionFor(double angle, {double? draw}) {
    final dir = Vector2(cos(angle), -sin(angle));
    final effectiveDraw = draw ?? bowDraw;
    return bowReleasePositionFor(angle) - dir * effectiveDraw;
  }

  Vector2 arrowLaunchCenterFor(double angle, {double? draw}) {
    final dir = Vector2(cos(angle), -sin(angle));
    // Arrow is center-anchored, so place its center half a shaft length beyond
    // the exact visible string/nock point.
    final nock = bowStringReleasePositionFor(angle, draw: draw);
    return nock + dir * (arrowLength / 2);
  }

  bool get isDead => health <= 0;
  bool get canAim => !isDead;
  bool get canFire => !isDead;

  /// Applies melee damage, clamped so health never becomes negative.
  void takeDamage(int amount) {
    if (amount <= 0 || isDead) return;
    health = (health - amount).clamp(0, hunterMaxHealth).toInt();
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
    if (isDead) {
      moveDirection = 0;
      return;
    }

    // Apply horizontal movement, scaled by dt (frame-rate independent).
    final oldX = position.x;
    if (moveDirection != 0) {
      position.x += moveDirection * hunterSpeed * dt;
    }

    // Clamp so the hunter cannot leave the battlefield.
    // clamp on num returns num; convert back to double for the position.
    position.x = position.x
        .clamp(hunterBoundaryLeft, (battlefieldWidth - wallThickness - hunterHalfWidth))
        .toDouble();

    // Block movement into a solid obstacle: if the new position overlaps an
    // obstacle, revert to the previous x so the Hunter never walks through.
    if (_overlapsObstacle()) {
      position.x = oldX;
    }

    // Stay anchored on the ground (feet at groundY).
    position.y = battlefieldHeight - groundHeight;

    // Face the direction of movement (defaults to facing right).
    if (moveDirection != 0) {
      facing = moveDirection.toDouble();
    }
  }

  /// Returns true if the Hunter's body rectangle overlaps any solid obstacle.
  bool _overlapsObstacle() {
    if (obstacles.isEmpty) return false;
    final body = collisionRect;
    for (final o in obstacles) {
      if (body.overlaps(o)) return true;
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Phase 9A artwork path (static visual prototype). Kept fully separate so
    // gameplay is untouched and the procedural fallback remains available.
    final v = visual;
    if (v != null && useArtwork) {
      _renderArtwork(canvas, v);
      return;
    }

    // PositionComponent local drawing coordinates start at the component's
    // top-left, even when the component is anchored at bottomCenter. Translate
    // to the feet (the component's bottom-center) before using the Hunter's
    // established feet-relative artwork coordinates. This keeps the visible
    // body inside the 48x76 bounds while position remains the world-space feet.
    canvas.save();
    canvas.translate(size.x / 2, size.y);

    // Feet-relative origin: +x is right and -y is up.
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

    canvas.restore();
  }

  /// Phase 9A static artwork render: draws the Hunter body sprite (feet-aligned,
  /// facing-correct), the Bow sprite (separate, rotated to [aim.worldAngle]), and
  /// a nocked Arrow sprite when aiming. Gameplay is not touched.
  void _renderArtwork(Canvas canvas, HunterVisual v) {
    canvas.save();
    canvas.translate(size.x / 2, size.y); // local coords: (0,0) = feet

    // --- Hunter body sprite, feet at origin, ~2x placeholder height ---
    final bodyH = v.bodyHeight;
    final bodyW = v.bodyWidthFor(bodyH);
    final flip = facing < 0; // face left by mirroring
    // Draw so the bottom of the sprite is at the feet (y=0). Flip the canvas
    // horizontally when facing left (Sprite.render has no flip option here).
    canvas.save();
    if (flip) {
      canvas.scale(-1, 1); // mirror around the feet origin (x=0)
    }
    v.body.render(
      canvas,
      position: Offset(-bodyW / 2, -bodyH),
      size: Vector2(bodyW, bodyH),
    );
    canvas.restore();

    // --- Bow sprite, separate component, grip at the front hand ---
    // Grip pivot around the torso/hand. Bow rotates to the aim direction.
    final angle = aim.active ? aim.worldAngle : (facing > 0 ? 0.0 : pi);
    final bowH = v.bowHeight;
    final bowW = v.bowWidthFor(bowH);
    // The bow art is a vertical bow; rotate it about its grip so it points
    // along the aim direction (up = -y), matching the existing bow pivot math.
    const gripY = -42.0; // same hand height as the placeholder bow
    canvas.save();
    canvas.translate(0, gripY);
    canvas.rotate(-angle);
    v.bow.render(
      canvas,
      // Center the bow sprite on the grip, slightly in front of the hand.
      position: Offset(-bowW / 2 + 6, -bowH / 2),
      size: Vector2(bowW, bowH),
    );
    canvas.restore();

    // --- Nocked arrow while aiming, pointing along the firing direction ---
    if (aim.active && aim.canFire) {
      final len = v.arrowLength;
      final ah = v.arrowHeightFor(len);
      canvas.save();
      canvas.translate(0, gripY);
      canvas.rotate(-angle);
      // Nock sits near the grip; arrow extends forward (+x in rotated frame).
      v.arrow.render(
        canvas,
        position: Offset(-len / 2 - 8, -ah / 2),
        size: Vector2(len, ah),
      );
      canvas.restore();
    }

    // --- Health bar (kept for gameplay readability) ---
    const barWidth = 40.0;
    const barHeight = 6.0;
    final ratio = (health / hunterMaxHealth).clamp(0.0, 1.0).toDouble();
    final barY = -bodyH - 10;
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

    canvas.restore();
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

    final landingTime = Projectile.timeToReachY(
      p0.y,
      vel.y,
          arrowGravity,
      battlefieldHeight - groundHeight,
    );
    if (landingTime == null) return;

    final dot = Paint()..color = const Color(0xCCFFFFFF);
    // The canvas is still translated to the Hunter's feet by render(). Convert
    // the world-space projectile positions back into that local feet-relative
    // coordinate system before drawing them.
    var stoppedAtBoundary = false;
    var lastTime = 0.0;
    for (double t = 0; t <= landingTime; t += 0.07) {
      final p = Projectile.position(p0, vel, arrowGravity, t);
      final outside = p.x <= wallThickness ||
          p.x >= battlefieldWidth - wallThickness ||
          p.y <= wallThickness ||
          p.y >= battlefieldHeight - groundHeight;
      if (outside) {
        stoppedAtBoundary = true;
        break;
      }
      final local = Offset(p.x - position.x, p.y - position.y);
      canvas.drawCircle(local, 3, dot);
      lastTime = t;
    }

    // Draw the final valid sample before a boundary. This keeps the preview
    // inside the same battlefield limits enforced by Arrow._step().
    if (!stoppedAtBoundary) {
      final landing = Projectile.position(p0, vel, arrowGravity, landingTime);
      canvas.drawCircle(
        Offset(landing.x - position.x, landing.y - position.y),
        3,
        dot,
      );
    } else if (lastTime > 0) {
      final last = Projectile.position(p0, vel, arrowGravity, lastTime);
      canvas.drawCircle(
        Offset(last.x - position.x, last.y - position.y),
        3,
        dot,
      );
    }
  }
}
