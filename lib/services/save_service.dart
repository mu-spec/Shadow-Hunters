import 'package:shared_preferences/shared_preferences.dart';

class SaveService {
  static const _keyUnlockedLevel = 'unlocked_level';
  static const _keyCompletedLevels = 'completed_levels';

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
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedLevel = (prefs.getInt(_keyUnlockedLevel) ?? 1).clamp(1, totalLevels).toInt();
    _completed..clear()..addAll((prefs.getStringList(_keyCompletedLevels) ?? []).map(int.tryParse).whereType<int>().where((n) => n >= 1 && n <= totalLevels));
  }
  Future<void> completeLevel(int level) async {
    if (level < 1 || level > totalLevels) return;
    _completed.add(level);
    if (level < totalLevels && level + 1 > _unlockedLevel) _unlockedLevel = level + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCompletedLevels, _completed.map((e) => '$e').toList());
    await prefs.setInt(_keyUnlockedLevel, _unlockedLevel);
  }
  Future<void> reset() async { _unlockedLevel = 1; _completed.clear(); final p = await SharedPreferences.getInstance(); await p.remove(_keyUnlockedLevel); await p.remove(_keyCompletedLevels); }
}
