import 'dart:ui';

import 'package:flame/game.dart';

import 'components/arena_background.dart';
import 'components/arena_title.dart';

/// The Flame game world for Shadow Hunters.
///
/// For Milestone 0A this only proves Flame renders: a background + a title.
/// Gameplay (player, aiming, enemies) will be added here in later phases.
class ShadowHuntersGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF18202B);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Simple proof-of-render world.
    add(ArenaBackground());
    add(ArenaTitle());
  }
}
