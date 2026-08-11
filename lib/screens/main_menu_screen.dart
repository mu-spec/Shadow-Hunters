import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/menu_button.dart';
import 'settings_screen.dart';
import 'level_select_screen.dart';

/// Main menu with Play / Settings / Exit.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _exitApp() {
    // Close the app on Android.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1016),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_drop_up, color: Color(0xFF7FD44E), size: 64),
              const SizedBox(height: 8),
              const Text(
                'SHADOW HUNTERS',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Color(0xFFE8F0F5),
                ),
              ),
              const SizedBox(height: 48),
              // Move only the three-button group. Their internal spacing and
              // horizontal centering remain unchanged, while SafeArea keeps
              // the group clear of system insets on landscape devices.
              Transform.translate(
                offset: const Offset(0, -28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MenuButton(
                      label: 'PLAY',
                      icon: Icons.play_arrow,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LevelSelectScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MenuButton(
                      label: 'SETTINGS',
                      icon: Icons.settings,
                      primary: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MenuButton(
                      label: 'EXIT',
                      icon: Icons.close,
                      primary: false,
                      onPressed: _exitApp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
