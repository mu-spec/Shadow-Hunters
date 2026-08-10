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
  Battlefield({this.width = worldWidth, this.height = worldHeight});

  final double width;
  final double height;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Back to front: sky/forest, then ground, then boundaries on top.
    add(ForestBackground(width: width, height: height));
    add(Ground(width: width, height: height));
    add(WorldBounds(width: width, height: height));

  }
}
