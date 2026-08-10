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
}
