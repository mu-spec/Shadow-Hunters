import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app/settings_scope.dart';
import '../game/shadow_hunters_game.dart';

/// Top-center boss health bar with the boss name. Only shown on boss levels.
class _BossHud extends StatelessWidget {
  const _BossHud({required this.game});
  final ShadowHuntersGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: game.bossHealthNotifier,
          builder: (context, ratio, _) {
            if (ratio < 0) return const SizedBox.shrink();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: game.bossNameNotifier,
                  builder: (context, name, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 14,
                      backgroundColor: const Color(0x88222A18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFE8FF9E),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Boss intro overlay shown at the start of a boss level.
class _BossIntro extends StatelessWidget {
  const _BossIntro({required this.game});
  final ShadowHuntersGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<bool>(
        valueListenable: game.bossIntroVisible,
        builder: (context, visible, _) {
          if (!visible) return const SizedBox.shrink();
          final name = game.levelData.bossName ?? 'FOREST GUARDIAN';
          final intro = game.levelData.bossIntro ?? '';
          return GestureDetector(
            onTap: game.dismissBossIntro,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black87,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BOSS',
                    style: TextStyle(
                      color: Color(0xFFE8FF9E),
                      fontSize: 22,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  if (intro.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        intro,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Text(
                    'TAP TO BEGIN',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Final V1 completion screen, shown after defeating the Forest Guardian.
class FinalCompletion extends StatelessWidget {
  const FinalCompletion();

  void _replayLevels(BuildContext context) =>
      Navigator.of(context).pop(); // back to Level Select

  void _mainMenu(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0E14),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forest, color: Color(0xFF7FD44E), size: 72),
          const SizedBox(height: 24),
          const Text(
            'ENCHANTED FOREST SAVED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE8FF9E),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SHADOW HUNTERS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
          ),
          const Text(
            'V1 COMPLETE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _replayLevels(context),
            child: const Text('REPLAY LEVELS'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _mainMenu(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('MAIN MENU'),
          ),
        ],
      ),
    );
  }
}

/// Wraps the Flame game in a `GameWidget` and overlays Flutter HUD controls.
///
/// The Flame `GameWidget` must fill the ENTIRE available gameplay area. It is
/// placed with `Positioned.fill` inside a full-screen `Stack` so it is never
/// sized to half the screen or offset toward one corner. Back / pause / HUD
/// controls are simple Flutter overlays that sit on top.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.levelNumber = 1, this.onCompleted});
  final int levelNumber;
  final VoidCallback? onCompleted;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ShadowHuntersGame? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build the game only once, passing the app-wide SettingsService so the
    // aim sensitivity setting is honoured by the gameplay.
    if (_game == null) {
      final settings = SettingsScope.of(context);
      _game = ShadowHuntersGame(settings: settings, levelNumber: widget.levelNumber, onLevelCompleted: widget.onCompleted);
    }
  }

  @override
  void dispose() {
    _game?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope(
      canPop: true,
      child: Scaffold(
        // Non-null so nothing bleeds through; the Flame background fills it.
        backgroundColor: const Color(0xFF0A0E14),
        body: game == null
            ? const SizedBox.expand()
            : LayoutBuilder(
                builder: (context, constraints) {
                  // The full available gameplay area:
                  final fullW = constraints.maxWidth;
                  final fullH = constraints.maxHeight;

                  return Stack(
                    children: [
                      // The Flame game fills the entire available area.
                      Positioned.fill(child: GameWidget(game: game)),

                      // Boss health bar + name (top center).
                      _BossHud(game: game),

                      // Boss intro overlay.
                      _BossIntro(game: game),

                      // Back button (top-left), pure Flutter overlay.
                      Positioned(
                        top: 12,
                        left: 12,
                        child: SafeArea(
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            tooltip: 'Back to menu',
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),

                      // Show available size in debug builds only (not the
                      // released player UI). Helps confirm full-screen layout.
                      if (kDebugMode)
                        Positioned(
                          top: 4,
                          left: 0,
                          child: IgnorePointer(
                            child: Text(
                              'game area: $fullW x $fullH',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ),

                      // Pause overlay: shown when the engine is paused.
                      Positioned.fill(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: game.pauseNotifier,
                          builder: (context, isPaused, _) {
                            if (!isPaused) return const SizedBox.shrink();
                            return Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'PAUSED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: game.resumeGame,
                                    child: const Text('RESUME'),
                                  ),
                                  ElevatedButton(
                                    onPressed: game.restart,
                                    child: const Text('RESTART'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                                    child: const Text('MAIN MENU'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned.fill(
                        child: ValueListenableBuilder<GameStatus>(
                          valueListenable: game.statusNotifier,
                          builder: (context, status, _) {
                            if (status == GameStatus.playing || game.paused) {
                              return const SizedBox.shrink();
                            }
                            final victory = status == GameStatus.victory;
                            // After defeating the final boss, show the V1
                            // completion screen instead of the generic victory.
                            if (victory && game.isBossLevel) {
                              return const FinalCompletion();
                            }
                            return Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(victory ? 'VICTORY' : 'DEFEAT', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 24),
                                  ElevatedButton(onPressed: game.restart, child: const Text('RETRY')),
                                  ElevatedButton(
                                    onPressed: victory
                                        ? () => Navigator.of(context).pop()
                                        : () => Navigator.of(context).popUntil((route) => route.isFirst),
                                    child: Text(victory ? 'CONTINUE' : 'MAIN MENU'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
