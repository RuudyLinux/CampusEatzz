import 'package:flutter/foundation.dart';

import '../data/models/cart_item.dart';
import '../data/models/order_models.dart';
import '../data/models/refund_models.dart';
import '../data/services/customer_service.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._service);

  final CustomerService _service;

  List<OrderSummary> _orders = const <OrderSummary>[];
  bool _loading = false;
  String? _error;

  // Recent order shown on home screen for 60 seconds after placement
  PlaceOrderResult? _recentOrder;
  DateTime? _recentOrderAt;

  List<OrderSummary> get orders => _orders;
  bool get isLoading => _loading;
  String? get error => _error;

  PlaceOrderResult? get recentOrder => _recentOrder;
  DateTime? get recentOrderAt => _recentOrderAt;

  bool get hasRecentOrder {
    if (_recentOrder == null || _recentOrderAt == null) return false;
    return DateTime.now().difference(_recentOrderAt!).inSeconds < 60;
  }

  int get recentOrderSecondsLeft {
    if (_recentOrderAt == null) return 0;
    final elapsed = DateTime.now().difference(_recentOrderAt!).inSeconds;
    return (60 - elapsed).clamp(0, 60);
  }

  void clearRecentOrder() {
    _recentOrder = null;
    _recentOrderAt = null;
    notifyListeners();
  }

  Future<void> loadOrders(String identifier) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _service.getOrders(identifier, limit: 30);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<OrderDetails> loadOrderDetails({
    required String identifier,
    required String orderRef,
  }) {
    return _service.getOrderDetails(identifier: identifier, orderRef: orderRef);
  }

  Future<CancelOrderResult> cancelOrder({
    required String identifier,
    required String orderRef,
  }) {
    return _service.cancelOrder(identifier: identifier, orderRef: orderRef);
  }

  Future<PlaceOrderResult> placeOrder({
    required String identifier,
    required String paymentMethod,
    required List<CartItem> items,
    int? canteenId,
    String? customerName,
    String? customerPhone,
    String orderType = 'takeaway',
  }) async {
    final result = await _service.placeOrder(
      identifier: identifier,
      paymentMethod: paymentMethod,
      cartItems: items,
      canteenId: canteenId,
      customerName: customerName,
      customerPhone: customerPhone,
      orderType: orderType,
    );
    _recentOrder = result;
    _recentOrderAt = DateTime.now();
    notifyListeners();
    return result;
  }
}
