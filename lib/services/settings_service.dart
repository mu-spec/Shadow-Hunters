import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, observable game settings for Shadow Hunters.
///
/// Holds user preferences (music, sound effects, vibration and aim
/// sensitivity) and persists them to local device storage so they survive an
/// app restart. Extends [ChangeNotifier] so UI can rebuild automatically when
/// a value changes. Every read/write is guarded so a failing or corrupted
/// preference store can NEVER crash the app — values fall back to safe defaults.
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
    try {
      final prefs = await SharedPreferences.getInstance();
      _music = prefs.getBool(_kMusic) ?? true;
      _sfx = prefs.getBool(_kSfx) ?? true;
      _vibration = prefs.getBool(_kVibration) ?? true;
      _aimSensitivity = _clampSensitivity(
        prefs.getDouble(_kAimSensitivity),
      );
    } catch (_) {
      // Storage failure: keep safe defaults; never crash.
      _music = true;
      _sfx = true;
      _vibration = true;
      _aimSensitivity = defaultAimSensitivity;
    }
    notifyListeners();
  }

  /// Sets and persists the music setting.
  Future<void> setMusic(bool value) async {
    if (value == _music) return;
    _music = value;
    notifyListeners();
    await _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMusic, value);
    });
  }

  /// Sets and persists the sound-effects setting.
  Future<void> setSfx(bool value) async {
    if (value == _sfx) return;
    _sfx = value;
    notifyListeners();
    await _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSfx, value);
    });
  }

  /// Sets and persists the vibration setting.
  Future<void> setVibration(bool value) async {
    if (value == _vibration) return;
    _vibration = value;
    notifyListeners();
    await _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kVibration, value);
    });
  }

  /// Sets and persists the aim sensitivity (clamped to valid bounds).
  Future<void> setAimSensitivity(double value) async {
    final clamped = _clampSensitivity(value);
    if (clamped == _aimSensitivity) return;
    _aimSensitivity = clamped;
    notifyListeners();
    await _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kAimSensitivity, clamped);
    });
  }

  /// Resets all settings to their defaults (music/sfx/vibration on, aim 1.0).
  Future<void> reset() async {
    _music = true;
    _sfx = true;
    _vibration = true;
    _aimSensitivity = defaultAimSensitivity;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kMusic);
      await prefs.remove(_kSfx);
      await prefs.remove(_kVibration);
      await prefs.remove(_kAimSensitivity);
    } catch (_) {
      // In-memory defaults are already applied; persistence failure is ignored.
    }
  }

  /// Clamps an aim-sensitivity value into the supported range, handling NaN.
  double _clampSensitivity(double? value) {
    if (value == null || value.isNaN) return defaultAimSensitivity;
    return value.clamp(minAimSensitivity, maxAimSensitivity).toDouble();
  }

  /// Runs a persistence write, swallowing any failure so settings changes
  /// never crash the app (the in-memory value is already applied).
  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // ignore: persistence failure should not affect gameplay.
    }
  }
}
