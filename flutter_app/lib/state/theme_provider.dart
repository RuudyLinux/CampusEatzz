import 'package:flutter/material.dart';

import '../data/services/app_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs) : _mode = ThemeMode.system {
    _load();
  }

  final AppPreferences _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _load() async {
    _mode = await _prefs.getThemeMode();
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs.saveThemeMode(_mode);
    notifyListeners();
  }
}
