import 'package:flutter/material.dart';

/// Placeholder settings screen (audio/music toggles arrive in a later phase).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1016),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE8F0F5),
        title: const Text('Settings'),
      ),
      body: const Center(
        child: Text(
          'Settings coming soon',
          style: TextStyle(color: Color(0xFF6B7A87), fontSize: 20),
        ),
      ),
    );
  }
}
