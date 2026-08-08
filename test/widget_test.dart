import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadow_hunters/app/app.dart';

void main() {
  setUp(() {
    // Give tests a working shared_preferences store.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash shows the game title', (tester) async {
    await tester.pumpWidget(const ShadowHuntersApp());
    expect(find.text('SHADOW HUNTERS'), findsOneWidget);
  });

  testWidgets('Splash navigates to the main menu', (tester) async {
    await tester.pumpWidget(const ShadowHuntersApp());

    // Wait out the splash timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
  });
}
