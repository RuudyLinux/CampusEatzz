import 'package:flutter/foundation.dart';

import '../data/models/cart_item.dart';
import '../data/models/menu_item.dart';
import '../data/services/app_preferences.dart';

class CartProvider extends ChangeNotifier {
  CartProvider(this._preferences);

  final AppPreferences _preferences;

  final List<CartItem> _items = <CartItem>[];
  bool _initialized = false;
  bool _isParcel = false;

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);
  bool get initialized => _initialized;
  bool get isParcel => _isParcel;

  void setParcel(bool value) {
    _isParcel = value;
    notifyListeners();
  }

  int get totalItems => _items.fold<int>(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  double get tax => subtotal * 0.05;
  double get total => subtotal + tax;

  int? get activeCanteenId {
    for (final item in _items) {
      if (item.canteenId != null && item.canteenId! > 0) {
        return item.canteenId;
      }
    }
    return null;
  }

  bool hasCanteenConflict(MenuItem item) {
    final active = activeCanteenId;
    if (active == null || _items.isEmpty) return false;
    if (item.canteenId <= 0) return false;
    return active != item.canteenId;
  }

  Future<void> clearAndAddMenuItem(MenuItem item) async {
    _items.clear();
    _items.add(CartItem.fromMenu(item));
    await _persist();
  }

  Future<void> load() async {
    final saved = await _preferences.getCart();
    _items
      ..clear()
      ..addAll(saved);
    _initialized = true;
    notifyListeners();
  }

  Future<void> addMenuItem(MenuItem item) async {
    final index = _items.indexWhere((element) => element.menuItemId == item.id);
    if (index >= 0) {
      final existing = _items[index];
      _items[index] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      _items.add(CartItem.fromMenu(item));
    }

    await _persist();
  }

  Future<void> increase(int menuItemId) async {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      return;
    }

    final current = _items[index];
    _items[index] = current.copyWith(quantity: current.quantity + 1);
    await _persist();
  }

  Future<void> decrease(int menuItemId) async {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) {
      return;
    }

    final current = _items[index];
    final nextQty = current.quantity - 1;
    if (nextQty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = current.copyWith(quantity: nextQty);
    }

    await _persist();
  }

  Future<void> updateSpecialInstruction(int menuItemId, String instruction) async {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) return;
    
    final current = _items[index];
    _items[index] = current.copyWith(specialInstruction: instruction);
    await _persist();
  }

  Future<void> remove(int menuItemId) async {
    _items.removeWhere((item) => item.menuItemId == menuItemId);
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    _isParcel = false;
    await _preferences.clearCart();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _preferences.saveCart(_items);
    notifyListeners();
  }
}
