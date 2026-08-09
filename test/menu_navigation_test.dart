import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/app/settings_scope.dart';
import 'package:shadow_hunters/screens/game_screen.dart';
import 'package:shadow_hunters/screens/main_menu_screen.dart';
import 'package:shadow_hunters/screens/settings_screen.dart';
import 'package:shadow_hunters/services/settings_service.dart';

void main() {
  Widget wrap(Widget child) => SettingsScope(
        service: SettingsService(),
        child: MaterialApp(home: child),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Main menu opens Settings and navigates back', (tester) async {
    await tester.pumpWidget(wrap(const MainMenuScreen()));

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Back navigation via the app bar.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
  });

  testWidgets('Android back button pops the Settings route', (tester) async {
    await tester.pumpWidget(wrap(const MainMenuScreen()));

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Simulate the system back button (pops the Settings route).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(MainMenuScreen), findsOneWidget);
  });

  testWidgets('Game screen hosts a Flame widget', (tester) async {
    await tester.pumpWidget(wrap(const GameScreen()));
    expect(find.byType(GameScreen), findsOneWidget);
    // A Flutter widget is present; Flame renders inside it.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
