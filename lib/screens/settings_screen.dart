import 'package:flutter/material.dart';

import '../app/settings_scope.dart';
import '../services/settings_service.dart';

/// Settings screen: music, sound effects, vibration and aim sensitivity.
///
/// Reads and writes the shared [SettingsService]. Because it is provided via
/// [SettingsScope] (an InheritedNotifier), the UI rebuilds automatically when a
/// setting changes, and all values persist locally.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1016),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE8F0F5),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          const _SectionHeader('Audio'),
          SwitchListTile(
            secondary: const Icon(Icons.music_note, color: Color(0xFF7FD44E)),
            title: const Text('Music', style: _tileText),
            value: settings.music,
            activeTrackColor: const Color(0xFF7FD44E),
            onChanged: settings.setMusic,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: Color(0xFF7FD44E)),
            title: const Text('Sound Effects', style: _tileText),
            value: settings.sfx,
            activeTrackColor: const Color(0xFF7FD44E),
            onChanged: settings.setSfx,
          ),
          const _SectionHeader('Feedback'),
          SwitchListTile(
            secondary: const Icon(Icons.vibration, color: Color(0xFF7FD44E)),
            title: const Text('Vibration', style: _tileText),
            value: settings.vibration,
            activeTrackColor: const Color(0xFF7FD44E),
            onChanged: settings.setVibration,
          ),
          const _SectionHeader('Controls'),
          ListTile(
            leading: const Icon(Icons.zoom_out_map, color: Color(0xFF7FD44E)),
            title: const Text('Aim Sensitivity', style: _tileText),
            subtitle: Slider(
              value: settings.aimSensitivity,
              min: SettingsService.minAimSensitivity,
              max: SettingsService.maxAimSensitivity,
              divisions: 15,
              activeColor: const Color(0xFF7FD44E),
              inactiveColor: const Color(0xFF3A4754),
              label: '${settings.aimSensitivity.toStringAsFixed(1)}x',
              onChanged: settings.setAimSensitivity,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _tileText = TextStyle(
  color: Color(0xFFE8F0F5),
  fontSize: 18,
);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6B7A87),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
