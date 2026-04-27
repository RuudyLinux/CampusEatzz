import 'package:flutter/foundation.dart';

import '../data/models/canteen.dart';
import '../data/models/menu_item.dart';
import '../data/services/canteen_service.dart';

class CanteenProvider extends ChangeNotifier {
  CanteenProvider(this._service);

  final CanteenService _service;

  List<Canteen> _canteens = const <Canteen>[];
  final Map<int, List<MenuItem>> _menuByCanteen = <int, List<MenuItem>>{};
  List<MenuItem>? _cachedAllItems;
  bool _loadingCanteens = false;
  bool _loadingMenu = false;
  String? _error;

  List<Canteen> get canteens => _canteens;
  bool get loadingCanteens => _loadingCanteens;
  bool get loadingMenu => _loadingMenu;
  String? get error => _error;

  List<MenuItem> menuFor(int canteenId) => _menuByCanteen[canteenId] ?? const <MenuItem>[];

  List<MenuItem> get allItems =>
      _cachedAllItems ??= _menuByCanteen.values
          .expand((items) => items)
          .toList(growable: false);

  Future<void> loadCanteens() async {
    _loadingCanteens = true;
    _error = null;
    notifyListeners();

    try {
      _canteens = await _service.fetchPublicCanteens();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingCanteens = false;
      notifyListeners();
    }
  }

  Future<void> loadMenu(int canteenId, {bool force = false}) async {
    if (!force && _menuByCanteen.containsKey(canteenId)) {
      return;
    }

    _loadingMenu = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _service.fetchMenuItems(canteenId);
      _menuByCanteen[canteenId] = rows;
      _cachedAllItems = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMenu = false;
      notifyListeners();
    }
  }
}
