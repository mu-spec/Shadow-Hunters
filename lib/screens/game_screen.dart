import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/shadow_hunters_game.dart';

/// Wraps the Flame game in a `GameWidget` and overlays a small back button.
///
/// Back navigation is handled by the Flutter Navigator (this screen is pushed
/// from the main menu), so the system back gesture / button pops it back.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ShadowHuntersGame _game;

  @override
  void initState() {
    super.initState();
    _game = ShadowHuntersGame();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: _game),
            // Floating back button overlaid on the game, purely Flutter UI.
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back to menu',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
