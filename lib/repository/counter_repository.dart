import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/counter_model.dart';

class CounterRepository extends ChangeNotifier {
  static const String _kCountersKey = 'fliptap_counters_list';
  static const String _kActiveIdKey = 'fliptap_active_counter_id';
  static const String _kThemeModeKey = 'fliptap_theme_mode';
  // Also keep legacy keys in sync for overlay compatibility
  static const String _kLegacyCounterKey = 'counter';

  List<CounterModel> _counters = [];
  String? _activeCounterId;
  ThemeMode _themeMode = ThemeMode.system;

  List<CounterModel> get counters => _counters;
  String? get activeCounterId => _activeCounterId;
  ThemeMode get themeMode => _themeMode;

  CounterModel? get activeCounter {
    if (_activeCounterId == null) return null;
    final index = _counters.indexWhere((c) => c.id == _activeCounterId);
    return index != -1 ? _counters[index] : null;
  }

  Future<void> init() async {
    await reload();
  }

  /// Reloads state from SharedPreferences (disk) to ensure synchronization
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _activeCounterId = prefs.getString(_kActiveIdKey);

    final themeStr = prefs.getString(_kThemeModeKey) ?? 'system';
    _themeMode = _parseThemeMode(themeStr);

    final rawJson = prefs.getString(_kCountersKey);
    if (rawJson != null) {
      try {
        final List<dynamic> parsed = jsonDecode(rawJson) as List<dynamic>;
        _counters = parsed
            .map((item) => CounterModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error parsing counters: $e');
        _createDefaultCounter();
      }
    } else {
      _createDefaultCounter();
    }

    // Ensure we have an active counter
    if (_counters.isNotEmpty) {
      if (_activeCounterId == null ||
          !_counters.any((c) => c.id == _activeCounterId)) {
        _activeCounterId = _counters.first.id;
      }
    }

    notifyListeners();
  }

  void _createDefaultCounter() {
    final defaultCounter = CounterModel(
      id: 'default_primary',
      name: 'Primary Counter',
      themeIndex: 0,
    );
    _counters = [defaultCounter];
    _activeCounterId = defaultCounter.id;
    _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_counters.map((c) => c.toJson()).toList());
    await prefs.setString(_kCountersKey, jsonString);
    if (_activeCounterId != null) {
      await prefs.setString(_kActiveIdKey, _activeCounterId!);
      // Sync legacy key for simple overlay reading
      final active = activeCounter;
      if (active != null) {
        await prefs.setInt(_kLegacyCounterKey, active.value);
      }
    }
  }

  Future<void> addCounter(String name, {int target = 0, int themeIndex = 0}) async {
    final newCounter = CounterModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      target: target,
      themeIndex: themeIndex,
    );
    _counters.add(newCounter);
    _activeCounterId = newCounter.id;
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> updateCounter(CounterModel updated) async {
    final index = _counters.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _counters[index] = updated;
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> deleteCounter(String id) async {
    // Prevent deleting the last remaining counter
    if (_counters.length <= 1) return;

    final index = _counters.indexWhere((c) => c.id == id);
    if (index != -1) {
      _counters.removeAt(index);
      if (_activeCounterId == id) {
        _activeCounterId = _counters.first.id;
      }
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> setActiveCounter(String id) async {
    if (_counters.any((c) => c.id == id)) {
      _activeCounterId = id;
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> incrementActive() async {
    final active = activeCounter;
    if (active != null) {
      final updated = active.copyWith(
        value: active.value + 1,
        history: List.from(active.history)..add(DateTime.now()),
      );
      await updateCounter(updated);
    }
  }

  Future<void> decrementActive() async {
    final active = activeCounter;
    if (active != null && active.value > 0) {
      final updated = active.copyWith(
        value: active.value - 1,
        // We can choose to log decrements or just remove the last log
        history: active.history.isNotEmpty
            ? (List.from(active.history)..removeLast())
            : active.history,
      );
      await updateCounter(updated);
    }
  }

  Future<void> resetActive() async {
    final active = activeCounter;
    if (active != null) {
      final updated = active.copyWith(
        value: 0,
        // Keep logs history but reset count, or clear history.
        // Let's clear history on reset.
        history: [],
      );
      await updateCounter(updated);
    }
  }

  ThemeMode _parseThemeMode(String val) {
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
    notifyListeners();
  }
}
