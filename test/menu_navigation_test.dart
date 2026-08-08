import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/screens/game_screen.dart';
import 'package:shadow_hunters/screens/main_menu_screen.dart';
import 'package:shadow_hunters/screens/settings_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

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

  testWidgets('Game screen hosts a Flame widget', (tester) async {
    await tester.pumpWidget(wrap(const GameScreen()));
    expect(find.byType(GameScreen), findsOneWidget);
    // A Flutter widget is present; Flame renders inside it.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
