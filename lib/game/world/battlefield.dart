import 'package:flame/components.dart';

import 'forest_background.dart';
import 'ground.dart';
import 'world_bounds.dart';

/// The Enchanted Forest battlefield.
///
/// Assembles the decorative background, ground, and world boundaries. The
/// Hunter and Skeleton are added by the game so their gameplay components stay
/// separate from the environment.
class Battlefield extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Back to front: sky/forest, then ground, then boundaries on top.
    add(ForestBackground());
    add(Ground());
    add(WorldBounds());

  }
}
