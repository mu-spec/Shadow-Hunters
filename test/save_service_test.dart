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

  test('levels 6-8 unlock sequentially and persist', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(5);
    expect(save.unlockedLevel, 6);
    await save.completeLevel(6);
    expect(save.unlockedLevel, 7);
    await save.completeLevel(7);
    expect(save.unlockedLevel, 8);

    final restored = SaveService();
    await restored.load();
    expect(restored.unlockedLevel, 8);
    expect(restored.completedLevels, containsAll([5, 6, 7]));
  });

  test('levels 9-11 unlock sequentially and persist', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(8);
    expect(save.unlockedLevel, 9);
    await save.completeLevel(9);
    expect(save.unlockedLevel, 10);
    await save.completeLevel(10);
    expect(save.unlockedLevel, 11);

    final restored = SaveService();
    await restored.load();
    expect(restored.unlockedLevel, 11);
    expect(restored.completedLevels, containsAll([8, 9, 10]));
  });

  test('levels 12-14 unlock sequentially and persist', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(11);
    expect(save.unlockedLevel, 12);
    await save.completeLevel(12);
    expect(save.unlockedLevel, 13);
    await save.completeLevel(13);
    expect(save.unlockedLevel, 14);

    final restored = SaveService();
    await restored.load();
    expect(restored.unlockedLevel, 14);
    expect(restored.completedLevels, containsAll([11, 12, 13]));
  });

  test('level 15 (boss) unlocks and persists', () async {
    final save = SaveService();
    await save.load();
    await save.completeLevel(14);
    expect(save.unlockedLevel, 15);

    final restored = SaveService();
    await restored.load();
    expect(restored.unlockedLevel, 15);
  });

  test('completing level 15 marks V1 complete and persists', () async {
    final save = SaveService();
    await save.load();
    expect(save.isV1Complete, isFalse);

    await save.completeLevel(15);
    expect(save.isV1Complete, isTrue);
    expect(save.completedLevels, contains(15));

    final restored = SaveService();
    await restored.load();
    expect(restored.isV1Complete, isTrue);
  });
}
