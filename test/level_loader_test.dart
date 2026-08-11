import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/levels/level_loader.dart';

void main() {
  test('valid V1 level data loads', () {
    final level = LevelLoader.fromJson({
      'id': 'level_1',
      'name': 'First Shot',
      'playerSpawn': {'x': 220, 'y': 600},
      'enemyType': 'skeleton',
      'enemySpawn': {'x': 2340, 'y': 600},
      'enemyCount': 1,
      'battlefield': {'theme': 'enchanted_forest'},
    });
    expect(level, isNotNull);
    expect(level!.enemyCount, 1);
  });

  test('zombie enemy type loads as valid level data', () {
    final level = LevelLoader.fromJson({
      'id': 'level_zombie',
      'name': 'Undead Throng',
      'playerSpawn': {'x': 220, 'y': 600},
      'enemyType': 'zombie',
      'enemySpawn': {'x': 1800, 'y': 600},
      'enemySpawns': [
        {'x': 1600, 'y': 600},
        {'x': 1900, 'y': 600},
      ],
      'enemyCount': 2,
      'battlefield': {'theme': 'enchanted_forest'},
    });
    expect(level, isNotNull);
    expect(level!.enemyType, 'zombie');
    expect(level.enemyCount, 2);
    expect(level.enemySpawns.length, 2);
  });

  test('malformed level data fails safely', () {
    expect(LevelLoader.fromJson({'id': 'bad'}), isNull);
    expect(LevelLoader.fromJson(<String, dynamic>{
      'id': 'bad',
      'name': 'Bad',
      'playerSpawn': {'x': 0, 'y': 0},
      'enemyType': 'goblin',
      'enemySpawn': {'x': 1, 'y': 1},
      'enemyCount': 1,
      'battlefield': {},
    }), isNull);
  });
}
