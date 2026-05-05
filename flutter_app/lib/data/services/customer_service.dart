import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/cart_item.dart';
import '../models/order_models.dart';
import '../models/refund_models.dart';
import '../models/wallet_models.dart';
import 'api_client.dart';

class CustomerService {
  CustomerService(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletInfo> getWallet(String identifier) async {
    final response = await _apiClient.request(
      'api/customer/wallet',
      queryParameters: <String, dynamic>{
        'identifier': identifier,
      },
      method: 'GET',
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load wallet');
    return WalletInfo.fromJson(_asMap(body['data']));
  }

  Future<List<WalletTransaction>> getWalletTransactions(
    String identifier, {
    int limit = 20,
  }) async {
    final response = await _apiClient.request(
      'api/customer/wallet/transactions',
      queryParameters: <String, dynamic>{
        'identifier': identifier,
        'limit': limit,
      },
      method: 'GET',
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load wallet transactions');

    final data = _asMap(body['data']);
    final rows = (data['transactions'] is List) ? (data['transactions'] as List) : const [];

    return rows
        .whereType<Map>()
        .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<WalletInfo> rechargeWallet({
    required String identifier,
    required double amount,
    String paymentGateway = 'flutter-app',
    String description = 'Wallet recharge from Flutter app',
  }) async {
    final response = await _apiClient.request(
      'api/customer/wallet/recharge',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
        'amount': amount,
        'paymentGateway': paymentGateway,
        'description': description,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to recharge wallet');

    final data = _asMap(body['data']);
    return WalletInfo(
      balance: _asDouble(data['balance']),
      currency: 'INR',
    );
  }

  Future<List<OrderSummary>> getOrders(String identifier, {int limit = 30}) async {
    final response = await _apiClient.request(
      'api/customer/orders',
      queryParameters: <String, dynamic>{
        'identifier': identifier,
        'limit': limit,
      },
      method: 'GET',
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load orders');

    final data = _asMap(body['data']);
    final rows = (data['orders'] is List) ? (data['orders'] as List) : const [];
    return rows
        .whereType<Map>()
        .map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<OrderDetails> getOrderDetails({
    required String identifier,
    required String orderRef,
  }) async {
    final response = await _apiClient.request(
      'api/customer/orders/$orderRef',
      queryParameters: <String, dynamic>{
        'identifier': identifier,
      },
      method: 'GET',
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load order details');

    return OrderDetails.fromJson(_asMap(body['data']));
  }

  Future<PlaceOrderResult> placeOrder({
    required String identifier,
    required String paymentMethod,
    required List<CartItem> cartItems,
    int? canteenId,
    String? customerName,
    String? customerPhone,
    String orderType = 'takeaway',
  }) async {
    final response = await _apiClient.request(
      'api/customer/orders',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
        'canteenId': canteenId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'orderType': orderType,
        'paymentMethod': paymentMethod,
        'items': cartItems
            .map((item) => <String, dynamic>{
                  'id': item.menuItemId,
                  'menuItemId': item.menuItemId,
                  'itemName': item.name,
                  'quantity': item.quantity,
                  'unitPrice': item.price,
                  'specialInstructions': item.specialInstruction,
                })
            .toList(growable: false),
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to place order');

    return PlaceOrderResult.fromJson(_asMap(body['data']));
  }

  Future<void> submitReview({
    required String identifier,
    required String orderRef,
    required int rating,
    required String reviewText,
  }) async {
    final response = await _apiClient.request(
      'api/customer/reviews',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
        'orderRef': orderRef,
        'rating': rating,
        'reviewText': reviewText,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to submit feedback');
  }

  Future<CancelOrderResult> cancelOrder({
    required String identifier,
    required String orderRef,
  }) async {
    final response = await _apiClient.request(
      'api/customer/orders/$orderRef/cancel',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to cancel order');

    return CancelOrderResult.fromJson(_asMap(body['data']));
  }

  Future<List<RefundInfo>> getRefunds(String identifier, {int limit = 20}) async {
    final response = await _apiClient.request(
      'api/customer/refunds',
      queryParameters: <String, dynamic>{
        'identifier': identifier,
        'limit': limit,
      },
      method: 'GET',
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load refunds');

    final data = _asMap(body['data']);
    final rows = (data['refunds'] is List) ? (data['refunds'] as List) : const [];
    return rows
        .whereType<Map>()
        .map((e) => RefundInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<RequestRefundResult> requestRefund({
    required String identifier,
    required String orderRef,
    required String reason,
  }) async {
    final response = await _apiClient.request(
      'api/customer/orders/$orderRef/refund',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
        'reason': reason,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to request refund');

    return RequestRefundResult.fromJson(_asMap(body['data']));
  }

  Future<RefundInfo?> getRefundStatus({
    required String identifier,
    required String orderRef,
  }) async {
    try {
      final response = await _apiClient.request(
        'api/customer/orders/$orderRef/refund',
        queryParameters: <String, dynamic>{
          'identifier': identifier,
        },
        method: 'GET',
      );

      final body = _asMap(response.data);
      if (body['success'] != true) return null;

      final data = body['data'];
      if (data == null) return null;
      return RefundInfo.fromJson(_asMap(data));
    } catch (_) {
      return null;
    }
  }

  /// Uploads profile image bytes and returns the relative URL from the server.
  Future<String> uploadProfileImage({
    required String identifier,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'identifier': identifier,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType('image', _imageSubtype(fileName)),
      ),
    });

    final response = await _apiClient.request(
      'api/customer/profile/upload-image',
      method: 'POST',
      data: formData,
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to upload profile image');
    final data = _asMap(body['data']);
    return (data['profileImageUrl'] ?? '').toString();
  }

  static String _imageSubtype(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
  }

  Future<void> submitContactMessage({
    required String identifier,
    required String subject,
    required String message,
    String? name,
    String? email,
  }) async {
    final response = await _apiClient.request(
      'api/customer/contact-messages',
      method: 'POST',
      data: <String, dynamic>{
        'identifier': identifier,
        'subject': subject,
        'message': message,
        'name': name,
        'email': email,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to send contact message');
  }
}

void _ensureSuccess(Map<String, dynamic> body, {required String fallback}) {
  if (body['success'] == true) {
    return;
  }
  throw Exception((body['message'] ?? fallback).toString());
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return <String, dynamic>{};
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '0').toString()) ?? 0;
}
