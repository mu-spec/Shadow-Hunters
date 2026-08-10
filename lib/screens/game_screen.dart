import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app/settings_scope.dart';
import '../game/shadow_hunters_game.dart';

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
