import 'dart:math' show sqrt;

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../aim/aim_state.dart';
import '../shadow_hunters_game.dart';

/// Pull-back bow aim control.
///
/// An *invisible* touch area covering the Hunter's full body (head to legs).
/// Aiming starts only when the initial touch lands on the body; dragging
/// backward pulls the bow; the shot fires in the OPPOSITE direction of the
/// drag. Uses [DragCallbacks] so the finger keeps being tracked even after it
/// moves away from the Hunter, and it supports diagonal aiming.
///
/// Added to the WORLD (not screen), so Flame converts screen<->world
/// coordinates for hit-testing automatically — touch detection stays accurate
/// even while the camera pans. The touch area is the Hunter's full-body rect
/// ([Hunter.aimTouchRect]).
class AimControl extends PositionComponent
    with HasGameReference<ShadowHuntersGame>, DragCallbacks {
  AimControl({
    required this.aim,
    this.onFire,
    Vector2? size,
  }) : super(size: size ?? Vector2(96, 96), anchor: Anchor.center);

  final AimState aim;
  final void Function(AimState)? onFire;

  /// Touch position (local coords) where the drag started.
  Vector2? _startLocal;

  /// Current touch position, accumulated via incremental [DragUpdateEvent.localDelta].
  Vector2? _current;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (game.paused) return;
    // Only begin aiming if the initial touch lands on the Hunter's full body.
    // `localPosition` is the touch in this component's local frame, and the
    // component is sized/positioned to the full body rect (world component, so
    // Flame handles the camera coordinate conversion automatically).
    final lp = event.localPosition;
    if (lp.x.abs() > size.x / 2 || lp.y.abs() > size.y / 2) {
      return; // touch outside the body rect -> do not aim
    }
    _startLocal = event.localPosition;
    _current = event.localPosition;
    aim.active = true;
    _updateAim(_current!);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (game.paused) return;
    final start = _startLocal;
    if (start == null) {
      _startLocal = event.localEndPosition;
      _current = event.localEndPosition;
      return;
    }
    _current = (_current ?? start) + event.localDelta;
    _updateAim(_current!);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _finish(fire: true);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _finish(fire: false);
  }

  void _updateAim(Vector2 current) {
    // Pull-back: the shot vector is `start - current` (opposite the drag).
    final px = _startLocal!.x - current.x;
    final py = _startLocal!.y - current.y;
    final dist = sqrt(px * px + py * py);

    if (dist < 2) {
      // Negligible pull: neutral, no power, below fire threshold.
      aim.power = 0;
      aim.worldAngle = 0;
      aim.pullDistance = 0;
      return;
    }

    aim.applyPull(px, py);

    // Aim sensitivity scales how much pull is needed for power.
    final sens = game.settings.aimSensitivity;
    aim.setPowerByDistance(dist * sens);
    aim.pullDistance = dist * sens;
  }

  void _finish({required bool fire}) {
    if (!aim.active) return;
    aim.active = false;
    // Minimum-pull gate: only fire if the pull passed the threshold.
    if (fire && aim.canFire) {
      onFire?.call(aim);
    }
    _startLocal = null;
    _current = null;
  }

  // The activation area is invisible — no render override needed.
}
