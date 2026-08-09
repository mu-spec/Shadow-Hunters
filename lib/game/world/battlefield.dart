import 'dart:ui' show Color;

import 'package:flame/components.dart';

import 'constants.dart';
import 'forest_background.dart';
import 'ground.dart';
import 'spawn_marker.dart';
import 'world_bounds.dart';

/// The Enchanted Forest prototype battlefield.
///
/// Assembles the decorative background, the ground, the world boundaries and
/// the player/enemy spawn markers into a single world. This is the placeholder
/// scene for Milestone 1A — it contains no actual characters or gameplay.
class Battlefield extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Back to front: sky/forest, then ground, then boundaries on top, then the
    // enemy spawn marker (the player is added by the game as the Hunter).
    add(ForestBackground());
    add(Ground());
    add(WorldBounds());

    add(SpawnMarker(
      position: enemySpawn,
      label: 'ENEMY SPAWN',
      color: const Color(0xFFFF5A5A), // red
    ));
  }
}
