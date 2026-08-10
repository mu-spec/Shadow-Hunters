import 'package:shared_preferences/shared_preferences.dart';

class SaveService {
  static const _keyUnlockedLevel = 'unlocked_level';
  static const _keyCompletedLevels = 'completed_levels';
  int _unlockedLevel = 1;
  final Set<int> _completed = {};
  int get unlockedLevel => _unlockedLevel;
  Set<int> get completedLevels => Set.unmodifiable(_completed);
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedLevel = (prefs.getInt(_keyUnlockedLevel) ?? 1).clamp(1, 5).toInt();
    _completed..clear()..addAll((prefs.getStringList(_keyCompletedLevels) ?? []).map(int.tryParse).whereType<int>().where((n) => n >= 1 && n <= 5));
  }
  Future<void> completeLevel(int level) async {
    if (level < 1 || level > 5) return;
    _completed.add(level);
    if (level < 5 && level + 1 > _unlockedLevel) _unlockedLevel = level + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCompletedLevels, _completed.map((e) => '$e').toList());
    await prefs.setInt(_keyUnlockedLevel, _unlockedLevel);
  }
  Future<void> reset() async { _unlockedLevel = 1; _completed.clear(); final p = await SharedPreferences.getInstance(); await p.remove(_keyUnlockedLevel); await p.remove(_keyCompletedLevels); }
}
