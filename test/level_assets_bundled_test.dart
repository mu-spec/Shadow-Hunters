import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/levels/level_loader.dart';

/// Verifies that the level JSON files are actually bundled as Flutter assets.
///
/// This reads from the REAL rootBundle (no mock), so it fails loudly if a level
/// file is missing from the asset bundle — which is exactly the failure mode
/// where the game silently falls back to the default single-enemy level.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('required level JSON files are bundled (loadable via rootBundle)',
      () async {
    const required = [
      'assets/levels/level_1.json',
      'assets/levels/level_2.json',
      'assets/levels/level_3.json',
      'assets/levels/level_4.json',
      'assets/levels/level_5.json',
      'assets/levels/level_6.json',
      'assets/levels/level_7.json',
      'assets/levels/level_8.json',
      'assets/levels/level_9.json',
      'assets/levels/level_10.json',
      'assets/levels/level_11.json',
      'assets/levels/level_12.json',
      'assets/levels/level_13.json',
      'assets/levels/level_14.json',
      'assets/levels/level_15.json',
    ];
    for (final path in required) {
      // rootBundle.loadString throws if the asset is not bundled.
      final raw = await rootBundle.loadString(path);
      expect(raw, isNotEmpty, reason: 'bundled asset "$path" should not be empty');
    }
  });

  test('every level 1-15 parses to valid data via the real asset bundle',
      () async {
    for (var i = 1; i <= 15; i++) {
      final level = await LevelLoader.load('assets/levels/level_$i.json');
      expect(level, isNotNull,
          reason: 'level_$i.json must load from the real asset bundle');
      expect(level!.enemyCount, greaterThanOrEqualTo(1));
    }
  });
}
