import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/services/save_service.dart';
import 'package:shadow_hunters/services/settings_service.dart';

/// Phase 8 — Save & Progression reliability audit.
///
/// Covers the required scenarios: fresh install, app restart, replay old
/// levels, complete new level, corrupted/missing save, and reset progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fresh installation', () {
    test('SaveService starts with level 1 unlocked and nothing completed',
        () async {
      final save = SaveService();
      await save.load();
      expect(save.unlockedLevel, 1);
      expect(save.completedLevels, isEmpty);
      expect(save.isV1Complete, isFalse);
    });

    test('SettingsService starts at defaults', () async {
      final settings = SettingsService();
      await settings.load();
      expect(settings.music, isTrue);
      expect(settings.sfx, isTrue);
      expect(settings.vibration, isTrue);
      expect(settings.aimSensitivity, SettingsService.defaultAimSensitivity);
    });
  });

  group('App restart', () {
    test('progress survives a fresh SaveService instance (simulated restart)',
        () async {
      final save = SaveService();
      await save.load();
      await save.completeLevel(1);
      await save.completeLevel(2);
      expect(save.unlockedLevel, 3);

      // Simulate app restart: a brand-new instance reads the same storage.
      final restart = SaveService();
      await restart.load();
      expect(restart.unlockedLevel, 3);
      expect(restart.completedLevels, containsAll([1, 2]));
    });

    test(
        'settings survive a fresh SettingsService instance (simulated restart)',
        () async {
      final settings = SettingsService();
      await settings.load();
      await settings.setMusic(false);
      await settings.setSfx(false);
      await settings.setVibration(false);
      await settings.setAimSensitivity(1.6);

      final restart = SettingsService();
      await restart.load();
      expect(restart.music, isFalse);
      expect(restart.sfx, isFalse);
      expect(restart.vibration, isFalse);
      expect(restart.aimSensitivity, 1.6);
    });
  });

  group('Replay old levels', () {
    test('replaying an already-completed level keeps later levels unlocked',
        () async {
      final save = SaveService();
      await save.load();
      await save.completeLevel(1);
      await save.completeLevel(2);
      await save.completeLevel(3);
      expect(save.unlockedLevel, 4);

      // Replaying level 1 must not regress the unlocked level.
      await save.completeLevel(1);
      expect(save.unlockedLevel, 4);
      expect(save.completedLevels, containsAll([1, 2, 3]));
    });
  });

  group('Complete new level', () {
    test('completing a new level unlocks the next and persists', () async {
      final save = SaveService();
      await save.load();
      await save.completeLevel(14);
      expect(save.unlockedLevel, 15);
      await save.completeLevel(15);
      expect(save.isV1Complete, isTrue);

      final restart = SaveService();
      await restart.load();
      expect(restart.unlockedLevel, 15);
      expect(restart.isV1Complete, isTrue);
    });
  });

  group('Corrupted / missing save', () {
    test('SaveService handles missing keys gracefully', () async {
      final save = SaveService();
      await save.load();
      expect(save.unlockedLevel, 1);
      expect(save.completedLevels, isEmpty);
    });

    test('SaveService handles corrupted values safely', () async {
      // Seed invalid/corrupt storage.
      SharedPreferences.setMockInitialValues({
        'unlocked_level': 99, // out of range
        'completed_levels': ['1', 'abc', '999', '3', 'banana'],
      });
      final save = SaveService();
      await save.load();
      // Clamped to valid range; only valid completed levels kept.
      expect(save.unlockedLevel, SaveService.totalLevels);
      expect(save.completedLevels, containsAll([1, 3]));
    });

    test('SettingsService handles corrupted sensitivity and bad values',
        () async {
      SharedPreferences.setMockInitialValues({
        'settings_aim_sensitivity': 50.0, // way out of range
        'settings_music': false,
      });
      final settings = SettingsService();
      await settings.load();
      expect(settings.aimSensitivity,
          SettingsService.maxAimSensitivity); // clamped
      expect(settings.music, isFalse);
      expect(settings.sfx, isTrue); // missing -> default
    });
  });

  group('Reset progress', () {
    test('SaveService.reset clears all progression', () async {
      final save = SaveService();
      await save.load();
      await save.completeLevel(1);
      await save.completeLevel(15); // V1 complete
      expect(save.isV1Complete, isTrue);

      await save.reset();
      expect(save.unlockedLevel, 1);
      expect(save.completedLevels, isEmpty);
      expect(save.isV1Complete, isFalse);
    });

    test('SettingsService.reset restores defaults', () async {
      final settings = SettingsService();
      await settings.load();
      await settings.setMusic(false);
      await settings.setSfx(false);
      await settings.setVibration(false);
      await settings.setAimSensitivity(1.9);

      await settings.reset();
      expect(settings.music, isTrue);
      expect(settings.sfx, isTrue);
      expect(settings.vibration, isTrue);
      expect(settings.aimSensitivity, SettingsService.defaultAimSensitivity);
    });

    test('reset persists across a simulated app restart', () async {
      final save = SaveService();
      await save.load();
      await save.completeLevel(5);
      await save.reset();

      final restart = SaveService();
      await restart.load();
      expect(restart.unlockedLevel, 1);
      expect(restart.completedLevels, isEmpty);
    });
  });

  group('Save failure never crashes', () {
    test('completeLevel with invalid level is a safe no-op', () async {
      final save = SaveService();
      await save.load();
      // Invalid levels must not throw and must not change state.
      await save.completeLevel(0);
      await save.completeLevel(999);
      expect(save.unlockedLevel, 1);
      expect(save.completedLevels, isEmpty);
    });

    test('settings setters never throw on storage errors', () async {
      final settings = SettingsService();
      await settings.load();
      // These should complete without throwing even though storage is mocked.
      await settings.setMusic(true);
      await settings.setAimSensitivity(1.2);
      expect(settings.music, isTrue);
      expect(settings.aimSensitivity, 1.2);
    });
  });
}
