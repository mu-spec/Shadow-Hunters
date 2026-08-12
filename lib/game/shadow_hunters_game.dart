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
import 'entities/boss_projectile.dart';
import 'entities/combat_feedback.dart';
import 'entities/enemy.dart';
import 'entities/forest_guardian.dart';
import 'entities/goblin.dart';
import 'entities/hunter.dart';
import 'entities/skeleton.dart';
import 'entities/zombie.dart';
import 'levels/level_data.dart';
import 'levels/level_loader.dart';
import 'ui/debug_hud.dart';
import 'world/battlefield.dart';
import 'world/constants.dart';
import 'world/obstacle.dart';

/// The Flame game world for Shadow Hunters.
///
/// Current game loop: projectile physics, Skeleton combat, hit zones, and
/// camera-follow gameplay for the active Phase 2 implementation. The
/// trajectory preview uses the same math as the flying Arrow.
enum GameStatus { playing, victory, defeat }

class ShadowHuntersGame extends FlameGame {
  ShadowHuntersGame({required SettingsService settings, this.levelNumber = 1, this.onLevelCompleted}) : _settings = settings;

  final int levelNumber;
  final VoidCallback? onLevelCompleted;

  final SettingsService _settings;
  SettingsService get settings => _settings;

  late LevelData levelData;
  double _levelWorldWidth = worldWidth;
  double _levelWorldHeight = worldHeight;
  late final Hunter hunter;
  late final MovementJoystick joystick;
  AimControl? aimControl;
  late final PauseButton pauseButton;
  late final DebugHud debugHud;

  /// Shared aim state (written by [aimControl], read by the [hunter]).
  final AimState aim = AimState();

  /// Pause-state notifier so the Flutter overlay (GameScreen) stays in sync
  /// with the actual engine pause state.
  final ValueNotifier<bool> pauseNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<GameStatus> statusNotifier = ValueNotifier<GameStatus>(GameStatus.playing);
  bool _completionReported = false;

  /// Notifies the Flutter overlay of the boss's current health ratio (0..1),
  /// or -1 when there is no boss. Used for the boss health bar.
  final ValueNotifier<double> bossHealthNotifier = ValueNotifier<double>(-1);

  /// Boss name shown in the HUD ('' when no boss).
  final ValueNotifier<String> bossNameNotifier = ValueNotifier<String>('');

  /// Whether the boss intro overlay should be visible.
  final ValueNotifier<bool> bossIntroVisible = ValueNotifier<bool>(false);

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

  /// Every enemy in the current level (Skeletons and/or Zombies). The game
  /// treats them uniformly through the shared [Enemy] interface.
  final List<Enemy> enemies = [];
  final Set<Arrow> _spentArrows = {};

  /// Live boss ranged projectiles.
  final List<BossProjectile> bossProjectiles = [];

  /// Whether the current level is the boss level.
  bool get isBossLevel => levelData.enemyType == 'forest_guardian';

  /// The active boss, if any.
  ForestGuardian? get boss {
    for (final e in enemies) {
      if (e is ForestGuardian) return e;
    }
    return null;
  }

  /// Authoritative total number of enemies the level spawned. Driven by the
  /// live [enemies] list so the HUD and Victory always agree with what is
  /// actually in the world.
  int get totalEnemies => enemies.length;

  /// Number of enemies that are still alive (not dead).
  int get liveEnemies => enemies.where((e) => !e.isDead).length;

  /// Convenience view of just the Skeleton enemies (used by Skeleton-specific
  /// tests); the full mixed roster lives in [enemies].
  List<Skeleton> get skeletons =>
      enemies.whereType<Skeleton>().toList(growable: false);

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
    statusNotifier.dispose();
    bossHealthNotifier.dispose();
    bossNameNotifier.dispose();
    bossIntroVisible.dispose();
    super.dispose();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    levelData = await LevelLoader.load('assets/levels/level_$levelNumber.json') ??
        LevelData(
          id: 'level_1',
          name: 'First Shot',
          playerSpawn: playerSpawn.clone(),
          enemyType: 'skeleton',
          enemySpawn: enemySpawn.clone(),
          enemySpawns: [enemySpawn.clone()],
          enemyCount: 1,
          battlefield: const {'theme': 'enchanted_forest'},
        );

    final battlefield = levelData.battlefield;
    final configuredWidth = (battlefield['width'] is num &&
            (battlefield['width'] as num).toDouble() > 0)
        ? (battlefield['width'] as num).toDouble()
        : _levelWorldWidth;
    final configuredHeight = (battlefield['height'] is num &&
            (battlefield['height'] as num).toDouble() > 0)
        ? (battlefield['height'] as num).toDouble()
        : worldHeight;
    _levelWorldWidth = configuredWidth;
    _levelWorldHeight = configuredHeight;
    await world.add(
      Battlefield(width: configuredWidth, height: configuredHeight),
    );

    // Simple static battlefield geometry (obstacles), added on top of the
    // background so they render visibly. Enemies ignore them (no pathfinding).
    for (final rect in levelData.obstacles) {
      await world.add(Obstacle(rect: rect));
    }

    // Hunter with the shared aim state, feet on the ground. Pass the level's
    // obstacles so the Hunter cannot walk through them.
    hunter = Hunter(
      position: levelData.playerSpawn.clone(),
      aim: aim,
      battlefieldWidth: _levelWorldWidth,
      battlefieldHeight: _levelWorldHeight,
      obstacles: levelData.obstacles,
    );
    await world.add(hunter);

    // Build the current level's declared enemy data (Skeleton, Zombie, ...).
    for (var i = 0; i < levelData.enemyCount; i++) {
      final enemy = _createEnemy(
        index: i,
        position: levelData.enemySpawns[i % levelData.enemySpawns.length].clone(),
      );
      enemies.add(enemy);
      await world.add(enemy);
    }

    // Pull-back aim control: an invisible touch area sized to fully surround
    // the Hunter's whole body, added to the WORLD so Flame converts
    // screen<->world coordinates for touch hit-testing automatically (accurate
    // even while the camera pans).
    // Hunter-body pull aiming remains in the WORLD so Flame performs the
    // camera-aware hit test. Movement remains in the viewport, allowing both
    // fingers to operate independently.
    final touchRect = hunter.aimTouchRect;
    final control = AimControl(
      aim: aim,
      onFire: fireShot,
      size: Vector2(touchRect.width, touchRect.height),
    )
      ..position = Vector2(touchRect.center.dx, touchRect.center.dy);
    aimControl = control;
    await world.add(control);

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

    // Show the boss intro on a boss level, pausing the simulation until the
    // player taps to begin.
    bossIntroVisible.value = isBossLevel;
    if (isBossLevel) {
      pauseEngine();
    }
    // Populate the boss HUD immediately (health bar + name).
    _updateBossHud();
  }

  /// Constructs the enemy for spawn [index] in the current level.
  ///
  /// The type comes from [LevelData.enemyTypeFor], which honors per-spawn
  /// `enemySpawnTypes` (enabling mixed levels such as Level 7) and otherwise
  /// falls back to the level's [LevelData.enemyType]. Supports `skeleton`
  /// (Milestone 2A), `zombie` (Milestone 4A), and `goblin` (Milestone 5A). All
  /// enemies share the [Enemy] base, so spawn/recycle/hit/Victory logic is
  /// identical regardless of type.
  Enemy _createEnemy({required int index, required Vector2 position}) {
    final patrolEnabled = levelData.battlefield['movingSkeleton'] == true;
    switch (levelData.enemyTypeFor(index)) {
      case 'forest_guardian':
        return ForestGuardian(
          position: position,
          hunter: hunter,
          battlefieldWidth: _levelWorldWidth,
          obstacles: levelData.obstacles,
          onRangedFire: fireBossRanged,
        );
      case 'zombie':
        return Zombie(
          position: position,
          hunter: hunter,
          patrolEnabled: patrolEnabled,
          battlefieldWidth: _levelWorldWidth,
          obstacles: levelData.obstacles,
        );
      case 'goblin':
        return Goblin(
          position: position,
          hunter: hunter,
          patrolEnabled: patrolEnabled,
          battlefieldWidth: _levelWorldWidth,
          obstacles: levelData.obstacles,
        );
      case 'skeleton':
      default:
        return Skeleton(
          position: position,
          hunter: hunter,
          patrolEnabled: patrolEnabled,
          battlefieldWidth: _levelWorldWidth,
          obstacles: levelData.obstacles,
        );
    }
  }

  /// Spawns a boss ranged projectile at [from] travelling along [dir].
  Future<void> fireBossRanged(Vector2 from, Vector2 dir) async {
    final p = BossProjectile(
      position: from,
      direction: dir,
      worldWidth: _levelWorldWidth,
      worldHeight: _levelWorldHeight,
    );
    // Temporary debug log (debug builds only): projectile launched.
    assert(() {
      debugPrint('[BossProjectile] PROJECTILE FIRED from $from dir $dir');
      return true;
    }());
    bossProjectiles.add(p);
    await world.add(p);
  }

  /// Returns true if the arrow flight segment [a]->[b] crosses any obstacle.
  bool _segmentHitsObstacle(Vector2 a, Vector2 b) {
    for (final rect in levelData.obstacles) {
      if (Obstacle.segmentIntersectsRect(a, b, rect)) return true;
    }
    return false;
  }

  /// Returns true if the segment [a]->[b] intersects [rect]. Used for swept
  /// boss-projectile collision against the Hunter's real collision bounds so a
  /// fast projectile cannot tunnel through the Hunter between frames.
  bool _segmentIntersectsRect(Vector2 a, Vector2 b, Rect rect) {
    // Quick rejection using the segment's bounding box.
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    if (maxX < rect.left || minX > rect.right ||
        maxY < rect.top || minY > rect.bottom) {
      return false;
    }
    // Endpoint inside the rect.
    if (rect.contains(Offset(a.x, a.y)) ||
        rect.contains(Offset(b.x, b.y))) {
      return true;
    }
    // Liang-Barsky clip against the rect edges.
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    double t0 = 0, t1 = 1;
    final p = <double>[-dx, dx, -dy, dy];
    final q = <double>[
      a.x - rect.left,
      rect.right - a.x,
      a.y - rect.top,
      rect.bottom - a.y,
    ];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return false; // parallel and outside
      } else {
        final r = q[i] / p[i];
        if (p[i] < 0) {
          if (r > t1) return false;
          if (r > t0) t0 = r;
        } else {
          if (r < t0) return false;
          if (r < t1) t1 = r;
        }
      }
    }
    return t0 <= t1;
  }

  /// Synchronizes the boss HUD notifiers with the live boss (if any).
  void _updateBossHud() {
    final b = boss;
    if (b == null) {
      bossHealthNotifier.value = -1;
      bossNameNotifier.value = '';
      return;
    }
    bossNameNotifier.value = levelData.bossName ?? 'FOREST GUARDIAN';
    bossHealthNotifier.value =
        (b.health / b.maxHealth).clamp(0.0, 1.0).toDouble();
  }

  /// Hides the boss intro overlay (called by the Flutter UI).
  void dismissBossIntro() {
    bossIntroVisible.value = false;
    // Resume the simulation that was paused for the intro (only if paused).
    if (paused) {
      resumeEngine();
    }
  }

  /// Scales the world so it fills the full screen height (no letterbox bars).
  /// The world's fixed height (720) maps to the device screen height so the
  /// battlefield fills the screen vertically on any device.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y > 0 && _levelWorldHeight > 0) {
      camera.viewfinder.zoom =
          (size.y / _levelWorldHeight).clamp(0.4, 4.0).toDouble();
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
    final arrow = Arrow(
      position: start,
      velocity: dir * shot.speed,
      worldWidth: _levelWorldWidth,
      worldHeight: _levelWorldHeight,
    );
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
  /// components and fully clears stale state. Returns a Future so the freshly
  /// respawned enemies are guaranteed to be mounted (and therefore tracked)
  /// before the next frame runs.
  Future<void> restart() async {
    // --- Arrows: remove every live arrow and clear the collection ---
    for (final arrow in arrows) {
      arrow.removeFromParent();
    }
    arrows.clear();
    _spentArrows.clear();
    // --- Boss projectiles ---
    for (final p in bossProjectiles) {
      p.removeFromParent();
    }
    bossProjectiles.clear();
    for (final enemy in enemies) {
      enemy.removeFromParent();
    }
    enemies.clear();
    for (var i = 0; i < levelData.enemyCount; i++) {
      final enemy = _createEnemy(
        index: i,
        position: levelData.enemySpawns[i % levelData.enemySpawns.length].clone(),
      );
      enemies.add(enemy);
      await world.add(enemy);
    }

    statusNotifier.value = GameStatus.playing;
    // Allow the level to be reported as completed again after a retry/restart.
    _completionReported = false;
    // Re-show the boss intro on restart for boss levels (pauses until tapped).
    bossIntroVisible.value = isBossLevel;
    if (isBossLevel) {
      pauseEngine();
    }

    // --- Hunter: spawn, full health, idle, default facing, zero input ---
    hunter.reset(levelData.playerSpawn.clone());

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

    // --- Pause: return to normal unpaused gameplay. On a boss level the
    // intro is being shown, so keep the engine paused until the player taps to
    // begin (the pause is released by dismissBossIntro).
    if (paused && !bossIntroVisible.value) {
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

    if (hunter.isDead) {
      statusNotifier.value = GameStatus.defeat;
    } else if (enemies.isNotEmpty && liveEnemies == 0) {
      // Victory requires EVERY spawned enemy to be dead. Using the alive count
      // (rather than assuming a single enemy) keeps multi-enemy levels such as
      // Level 5 from triggering Victory after only one enemy dies.
      statusNotifier.value = GameStatus.victory;
      if (!_completionReported) {
        _completionReported = true;
        onLevelCompleted?.call();
      }
    }

    // Keep the boss HUD in sync with the live boss.
    _updateBossHud();

    // Drop arrows that have cleaned themselves up (stuck-then-expired or hit
    // their max lifetime), so the tracked list stays in sync with the world.
    // Resolve each Arrow against obstacles first (so it cannot pass through a
    // solid obstacle), then against every enemy's head/body hit zones.
    for (final arrow in List<Arrow>.from(arrows)) {
      if (!arrow.flying || _spentArrows.contains(arrow)) continue;

      // Obstacle collision: the arrow stops at the first obstacle its flight
      // segment crosses, so it never passes through solid geometry.
      final prevPos = previousArrowPositions[arrow] ?? arrow.position;
      if (_segmentHitsObstacle(prevPos, arrow.position)) {
        _spentArrows.add(arrow);
        arrow.removeFromParent();
        continue;
      }

      for (final enemy in List<Enemy>.from(enemies)) {
        if (enemy.isDead) continue;
        final zone = enemy.hitZoneAlongPath(
          previousArrowPositions[arrow] ?? arrow.position,
          arrow.position,
        );
        if (zone != null) {
          final headshot = zone == EnemyHitZone.head;
          final damage = enemy.damageFor(zone);
          enemy.takeDamage(damage);
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

    // --- Boss ranged projectile resolution ---
    for (final p in List<BossProjectile>.from(bossProjectiles)) {
      if (p.spent) continue;
      // Stop projectiles at solid obstacles.
      if (_segmentHitsObstacle(
        p.previousPosition,
        p.position,
      )) {
        p.consume();
        continue;
      }
      // Damage the Hunter on contact using a SWEPT segment-vs-rect test over
      // this frame's motion against the Hunter's REAL gameplay collision bounds
      // (collisionRect). This prevents a fast projectile from tunneling
      // through the Hunter between frames, and uses the exact hitbox the game
      // world considers the Hunter (not an assumed position/size).
      if (_segmentIntersectsRect(
        p.previousPosition,
        p.position,
        hunter.collisionRect,
      )) {
        // Temporary debug log (debug builds only).
        assert(() {
          debugPrint('[BossProjectile] PROJECTILE/HUNTER INTERSECTION '
              'prev=${p.previousPosition} cur=${p.position} '
              'hunter=${hunter.collisionRect}');
          debugPrint('[BossProjectile] HUNTER DAMAGE APPLIED '
              '${bossRangedDamage.toInt()}');
          debugPrint('[BossProjectile] PROJECTILE REMOVED');
          return true;
        }());
        hunter.takeDamage(bossRangedDamage.toInt());
        p.consume(); // removed immediately, damages exactly once
        continue;
      }
    }
    // Remove only projectiles that are genuinely finished: consumed by a hit,
    // an obstacle, or expired/left the world. A freshly-added projectile may be
    // temporarily not-mounted while Flame finishes adding it to the world; the
    // ForestGuardian's onRangedFire callback does not await fireBossRanged, so
    // using `!isMounted` here would drop a brand-new projectile from tracking
    // before it mounts — the projectile would then render and move but never be
    // checked against the Hunter. `spent` is the authoritative done signal.
    bossProjectiles.removeWhere((p) => p.spent);

    // Only prune enemies that have actually finished dying and left the world.
    // A live enemy must never be dropped from tracking: if it is removed (e.g.
    // while its mount is still pending right after a Restart), the HUD enemy
    // count and Victory would both lose sight of it, letting a multi-enemy
    // level like Level 5 report one enemy and trigger Victory early.
    enemies.removeWhere((e) => !e.isMounted && e.isDead);

    // Block movement while paused (Flame already freezes arrow updates).
    hunter.moveDirection = paused ? 0 : joystick.horizontalDirection;

    final control = aimControl;
    if (control != null && control.isMounted) {
      final rect = hunter.aimTouchRect;
      control
        ..position = Vector2(rect.center.dx, rect.center.dy)
        ..size = Vector2(rect.width, rect.height);
    }

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
      camera.viewfinder.zoom > 0 ? size.x / camera.viewfinder.zoom : _levelWorldWidth;

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
      worldWidth: _levelWorldWidth,
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
          'maxCamX=${(_levelWorldWidth - visibleW).round()} '
          'gameW=${size.x.round()} '
          'zoom=${camera.viewfinder.zoom.toStringAsFixed(2)}',
        );
      }
    }
  }
}
