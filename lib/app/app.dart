import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';

/// Root application widget.
///
/// Deliberately keeps Flutter navigation/menus separate from the Flame game
/// world. The game is only mounted when the user taps "Play".
class ShadowHuntersApp extends StatelessWidget {
  const ShadowHuntersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow Hunters',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1016),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7FD44E),
          secondary: Color(0xFFFFD24E),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFFE8F0F5),
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
