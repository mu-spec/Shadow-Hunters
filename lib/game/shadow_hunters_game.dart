import 'dart:math' show cos, pi, sin;

import 'package:flame/components.dart' show Anchor;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'aim/aim_state.dart';
import 'camera/camera_follow.dart';
import 'controls/aim_control.dart';
import 'controls/movement_joystick.dart';
import 'controls/pause_button.dart';
import 'entities/arrow.dart';
import 'entities/combat_feedback.dart';
import 'entities/hunter.dart';
import 'entities/skeleton.dart';
import 'ui/debug_hud.dart';
import 'world/battlefield.dart';
import 'world/constants.dart';

/// The Flame game world for Shadow Hunters.
///
/// Current game loop: projectile physics, Skeleton combat, hit zones, and
/// camera-follow gameplay for the active Phase 2 implementation. The
/// trajectory preview uses the same math as the flying Arrow.
class ShadowHuntersGame extends FlameGame {
  ShadowHuntersGame({required SettingsService settings}) : _settings = settings;

  final SettingsService _settings;
  SettingsService get settings => _settings;

  late final Hunter hunter;
  late final MovementJoystick joystick;
  late final AimControl aimControl;
  late final PauseButton pauseButton;
  late final DebugHud debugHud;

  /// Shared aim state (written by [aimControl], read by the [hunter]).
  final AimState aim = AimState();

  /// Pause-state notifier so the Flutter overlay (GameScreen) stays in sync
  /// with the actual engine pause state.
  final ValueNotifier<bool> pauseNotifier = ValueNotifier<bool>(false);

  /// When true, the on-screen diagnostic debug HUD is shown. Hidden by default
  /// for normal players; kept behind this flag for development/diagnostics.
  /// Named `showDebugHud` (not `debugMode`) to avoid overriding Flame's
  /// inherited `Component.debugMode`.
  bool showDebugHud = false;

  /// Current camera X (world units at the top-left of the viewport). Updated
  /// smoothly in [update]; kept as a field so we can lerp instead of snapping.
  double _camX = 0;

  /// The camera X we are smoothly moving toward (dead-zone target).
  double _camTargetX = 0;

  /// Accumulated time used to throttle the temporary camera-follow log.
  double _followLogTimer = 0;

  /// All live arrows currently in the world (flying or stuck).
  final List<Arrow> arrows = [];
  final List<Skeleton> skeletons = [];
  final Set<Arrow> _spentArrows = {};

  /// Human-readable description of the most recent fired shot.
  String lastShot = 'none';

  @override
  Color backgroundColor() => const Color(0xFF0A0E14);

  /// Temporary development diagnostics (not shown to the player). Logs the
  /// actual available size and camera state so we can verify the full-screen
  /// layout. Prints only when [showDebugHud] is on to avoid noise.
  void _logDiagnostics(String label) {
    if (!showDebugHud) return;
    // ignore: avoid_print
    print(
      '$label: game.size=${size.x.round()}x${size.y.round()} '
      'viewport=${camera.viewport.size.x.round()}x${camera.viewport.size.y.round()} '
      'viewportVirtual=${camera.viewport.virtualSize.x.round()}x${camera.viewport.virtualSize.y.round()} '
      'viewportPos=${camera.viewport.position.x.round()},${camera.viewport.position.y.round()} '
      'viewfinderPos=${camera.viewfinder.position.x.round()},${camera.viewfinder.position.y.round()} '
      'zoom=${camera.viewfinder.zoom.toStringAsFixed(2)} '
      'playerSpawn=${hunter.position.x.round()},${hunter.position.y.round()}',
    );
  }

  @override
  void dispose() {
    pauseNotifier.dispose();
    super.dispose();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await world.add(Battlefield());

    // Hunter with the shared aim state, feet on the ground.
    hunter = Hunter(position: playerSpawn.clone(), aim: aim);
    await world.add(hunter);

    // Milestone 2A: one basic melee Skeleton on the battlefield.
    final skeleton = Skeleton(position: enemySpawn.clone(), hunter: hunter);
    skeletons.add(skeleton);
    await world.add(skeleton);

    // Pull-back aim control: an invisible touch area sized to fully surround
    // the Hunter's whole body, added to the WORLD so Flame converts
    // screen<->world coordinates for touch hit-testing automatically (accurate
    // even while the camera pans).
    // Screen-space controls & HUD. The right half is the dedicated aim region;
    // the left joystick and right aim drag can therefore receive separate
    // pointers simultaneously.
    aimControl = AimControl(aim: aim, onFire: fireShot)
      ..position = Vector2(size.x / 2, 0)
      ..size = Vector2(size.x / 2, size.y);
    camera.viewport.add(aimControl);

    // Screen-space controls & HUD (unaffected by the camera).
    //
    // IMPORTANT: these are added to the camera VIEWPORT, not the game root, so
    // they are positioned in screen space and stay fixed while the camera pans.
    joystick = MovementJoystick();
    pauseButton = PauseButton();
    debugHud = DebugHud();
    camera.viewport
      ..add(joystick)
      ..add(pauseButton)
      ..add(debugHud);

    // --- Fixed camera setup (R6 camera-anchor repair) ---
    //
    // The world uses top-left based coordinates: ForestBackground starts at
    // Vector2.zero(), size 2560x720, ground at y=600, player spawn (220,600).
    // To map world origin (0,0) to the top-left of the viewport, anchor the
    // viewfinder at its top-left and point it at the world origin.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    _logDiagnostics('onLoad');
  }

  /// Scales the world so it fills the full screen height (no letterbox bars).
  /// The world's fixed height (720) maps to the device screen height so the
  /// battlefield fills the screen vertically on any device.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y > 0 && worldHeight > 0) {
      camera.viewfinder.zoom =
          (size.y / worldHeight).clamp(0.4, 4.0).toDouble();
    }
    if (aimControl.isMounted) {
      aimControl
        ..position = Vector2(size.x / 2, 0)
        ..size = Vector2(size.x / 2, size.y);
    }
    _logDiagnostics('onGameResize');
  }

  /// Fires one arrow from the hunter's bow using the released [AimState].
  /// Public so tests and callbacks can trigger a shot.
  Future<void> fire(AimState a) async {
    if (hunter.isDead) return;
    // Compatibility entry point for callers that explicitly fire current aim.
    final shot = ShotData(
      worldAngle: a.worldAngle,
      power: a.power,
      speed: a.speed,
      facing: a.facing,
      pullDistance: a.pullDistance,
      draw: hunter.bowDraw,
      launchCenter: hunter
          .arrowLaunchCenterFor(a.worldAngle, draw: hunter.bowDraw)
          .clone(),
    );
    await fireShot(shot);
  }

  Future<void> fireShot(ShotData shot) async {
    if (hunter.isDead) return;
    final dir = Vector2(cos(shot.worldAngle), -sin(shot.worldAngle));
    // Use the immutable release snapshot; aim.active may already be false.
    final start = shot.launchCenter.clone();
    final arrow = Arrow(position: start, velocity: dir * shot.speed);
    arrows.add(arrow);
    await world.add(arrow);

    final deg = (shot.worldAngle * 180 / pi).round();
    lastShot =
        'arrow #${arrows.length} angle $deg° power ${shot.power.toStringAsFixed(2)} '
          '(facing ${shot.facing > 0 ? "R" : "L"})';
  }

  /// Pauses the whole game simulation using Flame's engine pause. Freezes
  /// Hunter movement, arrows, gravity, camera follow and timers immediately.
  void pauseGame() {
    aim.active = false; // drop any in-progress aim so nothing fires on resume
    pauseEngine();
    pauseNotifier.value = true;
  }

  /// Resumes the game simulation from the exact paused state (no dt jump).
  void resumeGame() {
    resumeEngine();
    pauseNotifier.value = false;
  }

  /// Single authoritative reset/restart. Returns all Phase 1 runtime state to
  /// its original condition: Hunter, aiming, arrows, camera, input, and pause.
  ///
  /// Safe to call repeatedly (even 10x) — it never stacks duplicate world
  /// components and fully clears stale state.
  void restart() {
    // --- Arrows: remove every live arrow and clear the collection ---
    for (final arrow in arrows) {
      arrow.removeFromParent();
    }
    arrows.clear();
    _spentArrows.clear();
    for (final skeleton in skeletons) {
      skeleton.removeFromParent();
    }
    skeletons.clear();
    final skeleton = Skeleton(position: enemySpawn.clone(), hunter: hunter);
    skeletons.add(skeleton);
    world.add(skeleton);

    // --- Hunter: spawn, full health, idle, default facing, zero input ---
    hunter.reset(playerSpawn);

    // --- Aiming: cancel active aim, reset power/pull/angle ---
    aim.active = false;
    aim.power = 0;
    aim.worldAngle = 0;
    aim.facing = 1;
    aim.pullDistance = 0;
    lastShot = 'none';

    // --- Input: zero the joystick direction (old drags don't persist) ---
    joystick.onDragStop();
    hunter.moveDirection = 0;

    // --- Camera: return to origin, reset follow target + smoothing state ---
    _camX = 0;
    _camTargetX = 0;
    _followLogTimer = 0;
    camera.viewfinder.position = Vector2.zero();

    // --- Pause: ensure we return to normal unpaused gameplay ---
    if (paused) {
      resumeEngine();
    }
    pauseNotifier.value = false;
  }

  @override
  void update(double dt) {
    // Capture positions before Flame advances Arrow physics this frame.
    final previousArrowPositions = <Arrow, Vector2>{
      for (final arrow in arrows) arrow: arrow.position.clone(),
    };
    super.update(dt);

    // Drop arrows that have cleaned themselves up (stuck-then-expired or hit
    // their max lifetime), so the tracked list stays in sync with the world.
    // Resolve each Arrow against the Skeleton head/body hit zones.
    for (final arrow in List<Arrow>.from(arrows)) {
      if (!arrow.flying || _spentArrows.contains(arrow)) continue;
      for (final skeleton in List<Skeleton>.from(skeletons)) {
        if (skeleton.isDead) continue;
        final zone = skeleton.hitZoneAlongPath(
          previousArrowPositions[arrow] ?? arrow.position,
          arrow.position,
        );
        if (zone != null) {
          final headshot = zone == SkeletonHitZone.head;
          final damage = skeleton.damageFor(zone);
          skeleton.takeDamage(damage);
          world.add(
            CombatFeedback(
              position: arrow.position.clone(),
              damage: damage,
              headshot: headshot,
            ),
          );
          world.add(
            ImpactEffect(
              position: arrow.position.clone(),
              headshot: headshot,
            ),
          );
          _spentArrows.add(arrow);
          arrow.removeFromParent();
          break;
        }
      }
    }
    arrows.removeWhere((a) {
      final removed = !a.isMounted;
      if (removed) _spentArrows.remove(a);
      return removed;
    });
    skeletons.removeWhere((s) => !s.isMounted);

    // Block movement while paused (Flame already freezes arrow updates).
    hunter.moveDirection = paused ? 0 : joystick.horizontalDirection;

    // AimControl is screen-space and stays fixed on the right half; it does
    // not follow the Hunter or camera.

    // When aiming, the Hunter faces the intended firing direction (not the
    // movement direction). Aiming takes precedence for facing.
    if (aim.active) {
      hunter.facing = aim.facing;
    }

    // R7: Smooth horizontal camera follow (dead-zone + lerp), preserving the
    // R6 top-left anchor and vertical position/zoom.
    _updateCameraFollow(dt);
  }

  /// Visible world width on screen (in world units), from the current device
  /// size and zoom. Adapts to any landscape aspect ratio.
  double get _visibleWorldWidth =>
      camera.viewfinder.zoom > 0 ? size.x / camera.viewfinder.zoom : worldWidth;

  /// Horizontal camera follow with a dead zone and smooth (non-snapping) lerp.
  /// Follows the Hunter only on the X axis; keeps him ~35% from the left so
  /// there's room ahead for aiming/arrows/enemies. Clamps to the world edges.
  void _updateCameraFollow(double dt) {
    // Do nothing while paused (also prevents camera jumps on pause/resume).
    if (paused) return;

    final visibleW = _visibleWorldWidth;
    final (nextX, nextTarget) = CameraFollow.next(
      hunterX: hunter.position.x,
      camX: _camX,
      camTargetX: _camTargetX,
      visibleWorldWidth: visibleW,
      worldWidth: worldWidth,
      dt: dt,
    );
    _camX = nextX;
    _camTargetX = nextTarget;
    // IMPORTANT: assign the FULL Vector2 via the setter. Writing `.x` on the
    // getter (camera.viewfinder.position.x = ...) mutates a temporary copy and
    // never updates the camera — that was the R11 bug (camera never followed).
    camera.viewfinder.position = Vector2(_camX, camera.viewfinder.position.y);

    // TEMPORARY R11 runtime logging (not visible UI). Throttled to ~2x/sec.
    if (showDebugHud) {
      _followLogTimer += dt;
      if (_followLogTimer >= 0.5) {
        _followLogTimer = 0;
        // ignore: avoid_print
        print(
          'R11 follow: hunterX=${hunter.position.x.round()} '
          'camX=${camera.viewfinder.position.x.round()} '
          'targetX=${_camTargetX.round()} '
          'visibleW=${visibleW.round()} '
          'maxCamX=${(worldWidth - visibleW).round()} '
          'gameW=${size.x.round()} '
          'zoom=${camera.viewfinder.zoom.toStringAsFixed(2)}',
        );
      }
    }
  }
}
