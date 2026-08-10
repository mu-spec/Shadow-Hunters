import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/services/save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh progress starts with only level 1 unlocked', () async {
    final save = SaveService();
    await save.load();
    expect(save.unlockedLevel, 1);
    expect(save.completedLevels, isEmpty);
  });

  test('completing levels unlocks the next level and persists progress', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(1);
    expect(save.unlockedLevel, 2);
    await save.completeLevel(2);
    expect(save.unlockedLevel, 3);
    await save.completeLevel(3);
    await save.completeLevel(4);
    expect(save.unlockedLevel, 5);
    expect(save.completedLevels, containsAll([1, 2, 3, 4]));

    final restored = SaveService();
    await restored.load();
    expect(restored.unlockedLevel, 5);
    expect(restored.completedLevels, containsAll([1, 2, 3, 4]));
  });

  test('replaying an old level does not lock later levels', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(1);
    await save.completeLevel(2);
    await save.completeLevel(1);
    expect(save.unlockedLevel, 3);
    expect(save.completedLevels, containsAll([1, 2]));
  });
}
