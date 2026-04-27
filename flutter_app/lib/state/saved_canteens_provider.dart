import 'package:flutter/material.dart';

import '../data/services/app_preferences.dart';

class SavedCanteensProvider extends ChangeNotifier {
  SavedCanteensProvider(this._prefs) {
    _load();
  }

  final AppPreferences _prefs;
  Set<int> _savedIds = <int>{};

  Set<int> get savedIds => _savedIds;
  bool isSaved(int canteenId) => _savedIds.contains(canteenId);

  Future<void> _load() async {
    final ids = await _prefs.getSavedCanteenIds();
    _savedIds = ids.toSet();
    notifyListeners();
  }

  Future<void> toggle(int canteenId) async {
    if (_savedIds.contains(canteenId)) {
      _savedIds.remove(canteenId);
    } else {
      _savedIds.add(canteenId);
    }
    await _prefs.saveSavedCanteenIds(_savedIds.toList());
    notifyListeners();
  }
}
