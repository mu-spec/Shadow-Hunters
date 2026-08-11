import 'package:flame/components.dart';

/// V1 data needed to construct one playable level.
class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.playerSpawn,
    required this.enemyType,
    required this.enemySpawn,
    required this.enemySpawns,
    required this.enemyCount,
    required this.battlefield,
    this.objective,
    this.enemySpawnTypes,
  });

  final String id;
  final String name;
  final Vector2 playerSpawn;
  final String enemyType;
  final Vector2 enemySpawn;
  final List<Vector2> enemySpawns;
  final int enemyCount;
  final Map<String, dynamic> battlefield;
  final String? objective;

  /// Optional per-spawn enemy type, parallel to [enemySpawns]. Lets a single
  /// level mix enemy types (e.g. Level 7 = Skeleton + Zombie). When null (or
  /// shorter than [enemySpawns]), [enemyType] is used for every spawn.
  final List<String>? enemySpawnTypes;

  /// Returns the enemy type for the spawn at [index]: the per-spawn type if
  /// one is declared for that index, otherwise the level's [enemyType].
  String enemyTypeFor(int index) {
    final types = enemySpawnTypes;
    if (types != null && index >= 0 && index < types.length) {
      return types[index];
    }
    return enemyType;
  }
}
