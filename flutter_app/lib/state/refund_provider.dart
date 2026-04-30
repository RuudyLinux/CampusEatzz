import 'package:flutter/foundation.dart';

import '../data/models/refund_models.dart';
import '../data/services/customer_service.dart';

class RefundProvider extends ChangeNotifier {
  RefundProvider(this._service);

  final CustomerService _service;

  bool _loading = false;
  String? _error;
  RequestRefundResult? _lastResult;

  bool get isLoading => _loading;
  String? get error => _error;
  RequestRefundResult? get lastResult => _lastResult;

  Future<RequestRefundResult> requestRefund({
    required String identifier,
    required String orderRef,
    required String reason,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.requestRefund(
        identifier: identifier,
        orderRef: orderRef,
        reason: reason,
      );
      _lastResult = result;
      return result;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<RefundInfo?> getRefundStatus({
    required String identifier,
    required String orderRef,
  }) {
    return _service.getRefundStatus(identifier: identifier, orderRef: orderRef);
  }
}
