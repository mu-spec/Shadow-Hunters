import 'package:shared_preferences/shared_preferences.dart';

/// Local device storage for game progress.
///
/// For now it tracks the highest unlocked level. This is the persistence
/// seam that later phases (level select unlock flow) build on.
class SaveService {
  static const String _keyUnlockedLevel = 'unlocked_level';

  int _unlockedLevel = 1;

  /// The highest level the player has unlocked (1-based).
  int get unlockedLevel => _unlockedLevel;

  /// Loads progress from local storage. Safe to call more than once.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedLevel = prefs.getInt(_keyUnlockedLevel) ?? 1;
    if (_unlockedLevel < 1) _unlockedLevel = 1;
  }

  /// Unlocks a level (and keeps the highest unlocked so far).
  Future<void> setUnlockedLevel(int level) async {
    if (level > _unlockedLevel) {
      _unlockedLevel = level;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUnlockedLevel, level);
    }
  }

  /// Wipes all stored progress (used by a "reset progress" option later).
  Future<void> reset() async {
    _unlockedLevel = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnlockedLevel);
  }
}
