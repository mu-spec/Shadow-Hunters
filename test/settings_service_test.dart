import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults are music/sfx/vibration on, aim sensitivity 1.0', () async {
    final settings = SettingsService();
    await settings.load();

    expect(settings.music, isTrue);
    expect(settings.sfx, isTrue);
    expect(settings.vibration, isTrue);
    expect(settings.aimSensitivity, SettingsService.defaultAimSensitivity);
  });

  test('changes are persisted and survive a fresh load', () async {
    final first = SettingsService();
    await first.load();
    await first.setMusic(false);
    await first.setSfx(false);
    await first.setVibration(false);
    await first.setAimSensitivity(1.5);

    // A brand-new instance simulates an app restart: it must read the saved values.
    final second = SettingsService();
    await second.load();

    expect(second.music, isFalse);
    expect(second.sfx, isFalse);
    expect(second.vibration, isFalse);
    expect(second.aimSensitivity, 1.5);
  });

  test('aim sensitivity is clamped to valid bounds', () async {
    final settings = SettingsService();
    await settings.load();

    await settings.setAimSensitivity(10.0);
    expect(settings.aimSensitivity, SettingsService.maxAimSensitivity);

    await settings.setAimSensitivity(0.0);
    expect(settings.aimSensitivity, SettingsService.minAimSensitivity);
  });

  test('setters notify listeners', () async {
    final settings = SettingsService();
    await settings.load();

    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setMusic(false);
    expect(notified, 1);
    await settings.setSfx(false);
    await settings.setVibration(false);
    await settings.setAimSensitivity(1.2);
    expect(notified, 4);
  });

  test('out-of-range stored aim sensitivity is clamped on load', () async {
    SharedPreferences.setMockInitialValues({
      'settings_aim_sensitivity': 50.0, // far above max
    });
    final settings = SettingsService();
    await settings.load();
    expect(settings.aimSensitivity, SettingsService.maxAimSensitivity);

    SharedPreferences.setMockInitialValues({
      'settings_aim_sensitivity': 0.0, // far below min
    });
    final clamped = SettingsService();
    await clamped.load();
    expect(clamped.aimSensitivity, SettingsService.minAimSensitivity);
  });

  test('missing/invalid stored sensitivity falls back to default', () async {
    // No stored value -> default.
    final missing = SettingsService();
    await missing.load();
    expect(missing.aimSensitivity, SettingsService.defaultAimSensitivity);

    // NaN stored value -> default (not crash).
    SharedPreferences.setMockInitialValues({
      'settings_aim_sensitivity': double.nan,
    });
    final nan = SettingsService();
    await nan.load();
    expect(nan.aimSensitivity, SettingsService.defaultAimSensitivity);
  });
}
