import 'package:flutter/foundation.dart';

import '../data/models/cart_item.dart';
import '../data/models/order_models.dart';
import '../data/services/customer_service.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._service);

  final CustomerService _service;

  List<OrderSummary> _orders = const <OrderSummary>[];
  bool _loading = false;
  String? _error;

  List<OrderSummary> get orders => _orders;
  bool get isLoading => _loading;
  String? get error => _error;

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

  Future<PlaceOrderResult> placeOrder({
    required String identifier,
    required String paymentMethod,
    required List<CartItem> items,
    int? canteenId,
    String? customerName,
    String? customerPhone,
  }) {
    return _service.placeOrder(
      identifier: identifier,
      paymentMethod: paymentMethod,
      cartItems: items,
      canteenId: canteenId,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }
}
