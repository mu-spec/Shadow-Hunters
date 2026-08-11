import 'dart:ui' show Rect;

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
    this.obstacles = const [],
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

  /// Simple static rectangular obstacles for V1 battlefield geometry, defined
  /// in world coordinates (top-left + width + height). Empty for levels with
  /// no geometry. Parsed from `battlefield.obstacles` in the level JSON.
  final List<Rect> obstacles;

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
