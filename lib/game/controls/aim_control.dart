import 'dart:math' show sqrt;

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../aim/aim_state.dart';
import '../shadow_hunters_game.dart';

/// Pull-back bow aim control.
///
/// Invisible Hunter-body pull-back aiming area. Dragging backward pulls the
/// bow; the shot fires in the OPPOSITE direction of the drag. Uses
/// [DragCallbacks] so the finger keeps being tracked after leaving the body.
class AimControl extends PositionComponent
    with HasGameReference<ShadowHuntersGame>, DragCallbacks {
  AimControl({
    required this.aim,
    this.onFire,
    Vector2? size,
  }) : super(size: size ?? Vector2(96, 96), anchor: Anchor.center);

  final AimState aim;
  final void Function(ShotData)? onFire;

  /// Touch position (local coords) where the drag started.
  Vector2? _startLocal;

  /// Current touch position, accumulated via incremental [DragUpdateEvent.localDelta].
  Vector2? _current;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (game.paused || game.hunter.isDead) return;
    // Flame dispatches this callback only after the component's hit-test area
    // has accepted the pointer. Do not perform a second local-coordinate
    // check here: PositionComponent local positions are not guaranteed to be
    // centered around zero (and the anchor does not make them so). The
    // component bounds are the single authoritative activation area.
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
    if (game.hunter.isDead) fire = false;
    // Snapshot every release value while the drawn bow is still visible.
    // In particular, launchCenter observes the non-zero bowDraw here.
    final shot = fire && aim.canFire
        ? ShotData(
            worldAngle: aim.worldAngle,
            power: aim.power,
            speed: aim.speed,
            facing: aim.facing,
            pullDistance: aim.pullDistance,
            draw: game.hunter.bowDraw,
            launchCenter: game.hunter
                .arrowLaunchCenterFor(aim.worldAngle, draw: game.hunter.bowDraw)
                .clone(),
          )
        : null;
    if (shot != null) onFire?.call(shot);
    aim.active = false;
    _startLocal = null;
    _current = null;
  }

  // The activation area is invisible — no render override needed.
}
