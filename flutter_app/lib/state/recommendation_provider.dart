import 'package:flutter/foundation.dart';

import '../data/models/recommendation_item.dart';
import '../data/services/recommendation_service.dart';

class RecommendationProvider extends ChangeNotifier {
  RecommendationProvider(this._service);

  final RecommendationService _service;

  RecommendationSection? _trending;
  RecommendationSection? _budgetMeals;
  RecommendationSection? _personal;

  bool _loadingTrending = false;
  bool _loadingBudget = false;
  bool _loadingPersonal = false;
  String? _error;

  RecommendationSection? get trending => _trending;
  RecommendationSection? get budgetMeals => _budgetMeals;
  RecommendationSection? get personal => _personal;
  bool get loadingTrending => _loadingTrending;
  bool get loadingBudget => _loadingBudget;
  bool get loadingPersonal => _loadingPersonal;
  bool get isLoading => _loadingTrending || _loadingBudget || _loadingPersonal;
  String? get error => _error;

  Future<void> loadAll({int userId = 0}) async {
    await Future.wait(<Future<void>>[
      loadTrending(),
      loadBudgetMeals(),
      loadPersonal(userId: userId),
    ]);
  }

  Future<void> loadTrending() async {
    if (_loadingTrending) return;
    _loadingTrending = true;
    notifyListeners();
    try {
      _trending = await _service.fetchTrending();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingTrending = false;
      notifyListeners();
    }
  }

  Future<void> loadBudgetMeals({double maxPrice = 150}) async {
    if (_loadingBudget) return;
    _loadingBudget = true;
    notifyListeners();
    try {
      _budgetMeals = await _service.fetchBudgetMeals(maxPrice: maxPrice);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingBudget = false;
      notifyListeners();
    }
  }

  Future<void> loadPersonal({int userId = 0}) async {
    if (_loadingPersonal) return;
    _loadingPersonal = true;
    notifyListeners();
    try {
      _personal = await _service.fetchPersonal(userId: userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingPersonal = false;
      notifyListeners();
    }
  }
}
