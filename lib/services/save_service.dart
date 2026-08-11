import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores the player's campaign progression.
///
/// Stores the highest unlocked level, the set of completed levels, and derives
/// V1 completion from whether the final boss level is completed. Every read and
/// write is guarded so a missing, corrupted, or failing preference store can
/// NEVER crash the game: on any failure it falls back to safe in-memory state
/// and logs the error in debug builds.
class SaveService {
  static const _keyUnlockedLevel = 'unlocked_level';
  static const _keyCompletedLevels = 'completed_levels';

  /// A single shared instance so every screen (Level Select, Settings reset)
  /// reads and writes the SAME in-memory state. This is essential so Reset
  /// Progress immediately affects what the Level Select screen shows and so a
  /// later completion cannot re-persist stale pre-reset progress.
  static final SaveService instance = SaveService();

  /// Total number of levels in the game (V1: 5 + Levels 6-8 in 4B +
  /// Levels 9-11 in 5B + Levels 12-14 in 6A + Level 15 boss in 7A).
  static const int totalLevels = 15;

  int _unlockedLevel = 1;
  final Set<int> _completed = {};
  int get unlockedLevel => _unlockedLevel;
  Set<int> get completedLevels => Set.unmodifiable(_completed);

  /// True once the final boss level (15) has been completed — the V1 campaign
  /// is fully cleared. Used to show the V1-complete state.
  bool get isV1Complete => _completed.contains(totalLevels);

  /// Loads progress from local storage, resetting in-memory state first.
  ///
  /// Safe to call more than once (e.g. on every app start). Corrupted or
  /// missing values fall back to defaults, and any storage failure is caught so
  /// gameplay can never be blocked.
  Future<void> load() async {
    // Start from a clean baseline regardless of prior state.
    _unlockedLevel = 1;
    _completed.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      _unlockedLevel =
          (prefs.getInt(_keyUnlockedLevel) ?? 1).clamp(1, totalLevels).toInt();
      final stored = prefs.getStringList(_keyCompletedLevels) ?? const [];
      _completed
        ..clear()
        ..addAll(stored
            .map(int.tryParse)
            .whereType<int>()
            .where((n) => n >= 1 && n <= totalLevels));
    } catch (e) {
      debugPrint('[SaveService] load failed, using defaults: $e');
    }
  }

  /// Marks [level] as completed, unlocking the next one, and persists.
  ///
  /// Returns true on success, false if the level is invalid or the write
  /// failed (so callers can react, though gameplay never depends on it).
  Future<bool> completeLevel(int level) async {
    if (level < 1 || level > totalLevels) return false;
    _completed.add(level);
    if (level < totalLevels && level + 1 > _unlockedLevel) {
      _unlockedLevel = level + 1;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _keyCompletedLevels, _completed.map((e) => '$e').toList());
      await prefs.setInt(_keyUnlockedLevel, _unlockedLevel);
      return true;
    } catch (e) {
      debugPrint('[SaveService] completeLevel failed: $e');
      // In-memory progress is kept; the write simply did not persist.
      return false;
    }
  }

  /// Resets all progression: level 1 unlocked, no completed levels, V1 not
  /// complete. In-memory state is reset immediately and then persisted (best
  /// effort). Returns true if the reset write succeeded.
  Future<bool> reset() async {
    _unlockedLevel = 1;
    _completed.clear();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_keyUnlockedLevel);
      await p.remove(_keyCompletedLevels);
      return true;
    } catch (e) {
      debugPrint('[SaveService] reset failed: $e');
      return false;
    }
  }
}
