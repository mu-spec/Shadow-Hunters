import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, observable game settings for Shadow Hunters.
///
/// Holds user preferences (music, sound effects, vibration and aim
/// sensitivity) and persists them to local device storage so they survive an
/// app restart. Extends [ChangeNotifier] so UI can rebuild automatically when
/// a value changes.
class SettingsService extends ChangeNotifier {
  // Storage keys
  static const String _kMusic = 'settings_music';
  static const String _kSfx = 'settings_sfx';
  static const String _kVibration = 'settings_vibration';
  static const String _kAimSensitivity = 'settings_aim_sensitivity';

  // Aim sensitivity bounds (multiplier applied to pointer movement).
  static const double minAimSensitivity = 0.5;
  static const double maxAimSensitivity = 2.0;
  static const double defaultAimSensitivity = 1.0;

  bool _music = true;
  bool _sfx = true;
  bool _vibration = true;
  double _aimSensitivity = defaultAimSensitivity;

  /// Whether background music is enabled.
  bool get music => _music;

  /// Whether sound effects are enabled.
  bool get sfx => _sfx;

  /// Whether vibration feedback is enabled.
  bool get vibration => _vibration;

  /// Aim sensitivity multiplier in the range
  /// [minAimSensitivity, maxAimSensitivity].
  double get aimSensitivity => _aimSensitivity;

  /// Loads persisted settings from local storage.
  ///
  /// Safe to call more than once; resets in-memory state to stored values.
  /// Any missing, invalid, or out-of-range stored value falls back to a safe
  /// default (booleans -> true) and the aim sensitivity is clamped to its
  /// supported range, so corrupted storage can never crash the app.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _music = prefs.getBool(_kMusic) ?? true;
    _sfx = prefs.getBool(_kSfx) ?? true;
    _vibration = prefs.getBool(_kVibration) ?? true;

    final storedSensitivity = prefs.getDouble(_kAimSensitivity);
    if (storedSensitivity == null || storedSensitivity.isNaN) {
      _aimSensitivity = defaultAimSensitivity;
    } else {
      // Clamp out-of-range stored values to the supported range.
      _aimSensitivity = storedSensitivity
          .clamp(minAimSensitivity, maxAimSensitivity)
          .toDouble();
    }

    notifyListeners();
  }

  /// Sets and persists the music setting.
  Future<void> setMusic(bool value) async {
    if (value == _music) return;
    _music = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusic, value);
  }

  /// Sets and persists the sound-effects setting.
  Future<void> setSfx(bool value) async {
    if (value == _sfx) return;
    _sfx = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfx, value);
  }

  /// Sets and persists the vibration setting.
  Future<void> setVibration(bool value) async {
    if (value == _vibration) return;
    _vibration = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibration, value);
  }

  /// Sets and persists the aim sensitivity (clamped to valid bounds).
  Future<void> setAimSensitivity(double value) async {
    // clamp on num returns num; convert back to double for the field.
    final clamped = value.clamp(minAimSensitivity, maxAimSensitivity).toDouble();
    if (clamped == _aimSensitivity) return;
    _aimSensitivity = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAimSensitivity, clamped);
  }
}
