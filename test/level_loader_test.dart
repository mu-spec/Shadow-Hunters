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
