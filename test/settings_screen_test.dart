import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/app/settings_scope.dart';
import 'package:shadow_hunters/screens/settings_screen.dart';
import 'package:shadow_hunters/services/save_service.dart';
import 'package:shadow_hunters/services/settings_service.dart';

void main() {
  Widget wrap(SettingsService settings) => SettingsScope(
        service: settings,
        child: const MaterialApp(home: SettingsScreen()),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Settings screen shows all controls', (tester) async {
    final settings = SettingsService();
    await settings.load();
    await tester.pumpWidget(wrap(settings));

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Aim Sensitivity'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
  });

  testWidgets('Toggling music persists the new value', (tester) async {
    final settings = SettingsService();
    await settings.load();
    await tester.pumpWidget(wrap(settings));

    expect(settings.music, isTrue);
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(settings.music, isFalse);
  });

  testWidgets('Moving the sensitivity slider updates the service',
      (tester) async {
    final settings = SettingsService();
    await settings.load();
    await tester.pumpWidget(wrap(settings));

    final slider = tester.widget<Slider>(find.byType(Slider));
    final mid = (slider.min + slider.max) / 2;
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(settings.aimSensitivity, isNot(slider.value));

    // Slider should now reflect a value within bounds.
    expect(settings.aimSensitivity, greaterThanOrEqualTo(mid - 0.5));
  });

  testWidgets('Reset Progress requires confirmation and resets on confirm',
      (tester) async {
    final settings = SettingsService();
    await settings.load();
    await settings.setMusic(false); // change a setting

    final save = SaveService();
    await save.load();
    await save.completeLevel(5); // some progress

    await tester.pumpWidget(wrap(settings));

    // Tap Reset Progress -> confirmation dialog appears; progress NOT yet reset.
    await tester.tap(find.text('Reset Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Progress?'), findsOneWidget);
    expect(save.completedLevels, isNotEmpty); // not reset yet

    // Cancel -> nothing changes.
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(save.completedLevels, isNotEmpty);
    expect(settings.music, isFalse);

    // Confirm -> reset happens.
    await tester.tap(find.text('Reset Progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();

    final restartedSave = SaveService();
    await restartedSave.load();
    expect(restartedSave.unlockedLevel, 1);
    expect(restartedSave.completedLevels, isEmpty);
    expect(settings.music, isTrue);
  });
}
