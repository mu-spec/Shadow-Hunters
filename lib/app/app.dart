import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../services/settings_service.dart';
import 'settings_scope.dart';

/// Root application widget.
///
/// Deliberately keeps Flutter navigation/menus separate from the Flame game
/// world. The game is only mounted when the user taps "Play".
///
/// Owns the single [SettingsService] instance and exposes it through
/// [SettingsScope] so all screens share the same persisted settings.
class ShadowHuntersApp extends StatefulWidget {
  const ShadowHuntersApp({super.key});

  @override
  State<ShadowHuntersApp> createState() => _ShadowHuntersAppState();
}

class _ShadowHuntersAppState extends State<ShadowHuntersApp> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    // Load persisted settings so preferences survive app restart.
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      service: _settings,
      child: MaterialApp(
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
      ),
    );
  }
}
