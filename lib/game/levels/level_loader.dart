import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flame/components.dart' show Vector2;

import 'level_data.dart';

/// Loads and validates the small V1 level JSON format.
///
/// Failures are intentionally non-fatal (the game falls back to a safe default
/// level), but the underlying cause is now logged in debug builds so a missing
/// or malformed asset is visible instead of being silently swallowed.
class LevelLoader {
  static Future<LevelData?> load(String assetPath) async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      // The asset itself could not be read. This is the classic symptom of the
      // levels directory not being bundled into the APK — surface it clearly.
      debugPrint(
        '[LevelLoader] FAILED to load asset "$assetPath": $e',
      );
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      return fromJson(decoded);
    } catch (e) {
      debugPrint(
        '[LevelLoader] FAILED to parse level "$assetPath": $e',
      );
      return null;
    }
  }

  static LevelData? fromJson(dynamic value) {
    try {
      if (value is! Map<String, dynamic>) {
        debugPrint('[LevelLoader] JSON root is not an object: $value');
        return null;
      }
      final player = _vector(value['playerSpawn']);
      final enemy = _vector(value['enemySpawn']);
      final enemySpawns = _vectors(value['enemySpawns']) ??
          (enemy == null ? <Vector2>[] : [enemy.clone()]);
      final battlefield = value['battlefield'];
      final id = value['id'];
      final name = value['name'];
      final enemyType = value['enemyType'];
      final count = value['enemyCount'];
      final objective = value['objective'];
      final knownEnemyTypes = const {'skeleton', 'zombie', 'goblin'};
      if (player == null || enemy == null || enemySpawns.isEmpty || battlefield is! Map ||
          id is! String || id.isEmpty || name is! String || name.isEmpty ||
          !knownEnemyTypes.contains(enemyType) || count is! int || count < 1) {
        debugPrint(
          '[LevelLoader] invalid level data: '
          'player=$player enemy=$enemy spawns=${enemySpawns.length} '
          'battlefield=$battlefield id=$id name=$name '
          'enemyType=$enemyType count=$count',
        );
        return null;
      }

      // Optional per-spawn enemy types (enables mixed-type levels). Validate
      // every declared type; lengths beyond enemySpawns are simply ignored.
      final spawnTypesRaw = value['enemySpawnTypes'];
      List<String>? spawnTypes;
      if (spawnTypesRaw is List) {
        final parsed = spawnTypesRaw.map((e) => e is String ? e : null).toList();
        if (parsed.every((t) => t != null && knownEnemyTypes.contains(t))) {
          spawnTypes = parsed.cast<String>();
        } else {
          debugPrint(
            '[LevelLoader] invalid enemySpawnTypes: $spawnTypesRaw',
          );
          return null;
        }
      }

      return LevelData(
        id: id,
        name: name,
        playerSpawn: player,
        enemyType: enemyType,
        enemySpawn: enemy,
        enemySpawns: enemySpawns,
        enemyCount: count,
        battlefield: Map<String, dynamic>.from(battlefield),
        objective: objective is String && objective.isNotEmpty ? objective : null,
        enemySpawnTypes: spawnTypes,
      );
    } catch (e) {
      debugPrint('[LevelLoader] unexpected error while parsing level: $e');
      return null;
    }
  }

  static List<Vector2>? _vectors(dynamic value) {
    if (value is! List) return null;
    final vectors = value.map(_vector).toList();
    return vectors.every((v) => v != null)
        ? vectors.cast<Vector2>()
        : null;
  }

  static Vector2? _vector(dynamic value) {
    if (value is! Map) return null;
    final x = value['x'];
    final y = value['y'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return null;
    return Vector2(x.toDouble(), y.toDouble());
  }
}
