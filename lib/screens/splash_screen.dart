import 'dart:async';

import 'package:flutter/material.dart';

import 'main_menu_screen.dart';

/// Simple branded splash that shows "SHADOW HUNTERS" then moves to the menu.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _goToMenu);
  }

  void _goToMenu() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B1016),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_drop_up, color: Color(0xFF7FD44E), size: 72),
            SizedBox(height: 8),
            Text(
              'SHADOW HUNTERS',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Color(0xFFE8F0F5),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(color: Color(0xFF6B7A87), letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
