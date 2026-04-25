import 'package:dio/dio.dart';

import '../models/canteen_admin_session.dart';
import 'api_client.dart';

class CanteenAdminService {
  CanteenAdminService(this._apiClient);

  final ApiClient _apiClient;

  Future<CanteenAdminSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _apiClient.request(
      'api/canteen-admin/login',
      method: 'POST',
      data: <String, dynamic>{
        'email': identifier,
        'password': password,
      },
      authenticated: false,
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Invalid canteen admin credentials.').toString());
    }

    final data = _asMap(body['data']);
    final token = (body['token'] ?? '').toString();
    final canteenId = _asInt(data['canteenId']);
    if (canteenId <= 0) {
      throw Exception('Login succeeded but canteen mapping is missing.');
    }

    return CanteenAdminSession(
      id: _asInt(data['id']),
      name: (data['name'] ?? 'Canteen Admin').toString(),
      email: (data['email'] ?? identifier).toString(),
      role: (data['role'] ?? 'canteen_admin').toString(),
      canteenId: canteenId,
      canteenName: (data['canteenName'] ?? 'Canteen').toString(),
      token: token,
      imageUrl: (data['imageUrl'] ?? '').toString(),
    );
  }

  Future<Map<String, dynamic>> getDashboard(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/dashboard',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    return _extractData(response);
  }

  Future<List<Map<String, dynamic>>> getOrders(
    CanteenAdminSession session, {
    String status = 'all',
    int limit = 300,
  }) async {
    final params = <String, dynamic>{
      'canteenId': session.canteenId,
      'limit': limit,
    };
    if (status.trim().isNotEmpty && status.trim().toLowerCase() != 'all') {
      params['status'] = status.trim().toLowerCase();
    }

    final response = await _authRequest(session, 'api/canteen/orders', queryParameters: params);
    final data = _extractData(response);
    return _asListOfMap(data['orders']);
  }

  Future<void> updateOrderStatus(
    CanteenAdminSession session, {
    required int orderId,
    required String status,
    required int estimatedTime,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/orders/$orderId/status',
      method: 'PATCH',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'status': status,
        'estimatedTime': estimatedTime,
        'changedBy': session.id,
        'notes': 'Updated from Flutter canteen admin app',
      },
    );

    _ensureSuccess(response);
  }

  Future<List<Map<String, dynamic>>> getMenuCategories(CanteenAdminSession session) async {
    final response = await _authRequest(session, 'api/canteen/menu-categories');
    final data = _extractData(response);
    return _asListOfMap(data['categories']);
  }

  Future<List<Map<String, dynamic>>> getMenuItems(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    final data = _extractData(response);
    return _asListOfMap(data['items']);
  }

  Future<String> uploadMenuItemImage(
    CanteenAdminSession session, {
    required String fileName,
    required List<int> bytes,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items/upload-image',
      method: 'POST',
      data: FormData.fromMap(<String, dynamic>{
        'canteenId': session.canteenId,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      }),
      headers: <String, dynamic>{
        'Content-Type': 'multipart/form-data',
      },
    );

    final data = _extractData(response);
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw Exception('Image upload did not return a valid URL.');
    }

    return url;
  }

  Future<void> addMenuItem(
    CanteenAdminSession session, {
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    required bool isVegetarian,
    String? imageUrl,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items',
      method: 'POST',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
        'isVegetarian': isVegetarian,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> updateMenuItem(
    CanteenAdminSession session, {
    required int itemId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    required bool isVegetarian,
    String? imageUrl,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items/$itemId',
      method: 'PUT',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
        'isVegetarian': isVegetarian,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> toggleMenuAvailability(
    CanteenAdminSession session, {
    required int itemId,
    required bool isAvailable,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items/$itemId/availability',
      method: 'PATCH',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'isAvailable': isAvailable,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> deleteMenuItem(
    CanteenAdminSession session, {
    required int itemId,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/menu-items/$itemId',
      method: 'DELETE',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );

    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> getReviews(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/reviews',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    return _extractData(response);
  }

  Future<void> respondToReview(
    CanteenAdminSession session, {
    required int reviewId,
    required String responseText,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/reviews/$reviewId/respond',
      method: 'POST',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'response': responseText,
      },
    );

    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> getReports(
    CanteenAdminSession session, {
    required String fromDate,
    required String toDate,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'canteenId': session.canteenId,
      'fromDate': fromDate,
      'toDate': toDate,
    };
    final normalizedStatus = (status ?? '').trim();
    if (normalizedStatus.isNotEmpty && normalizedStatus.toLowerCase() != 'all') {
      params['status'] = normalizedStatus;
    }

    final response = await _authRequest(session, 'api/canteen/reports', queryParameters: params);
    return _extractData(response);
  }

  Future<Map<String, dynamic>> getWallet(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/wallet',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    return _extractData(response);
  }

  Future<Map<String, dynamic>> getSettings(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/settings',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    return _extractData(response);
  }

  Future<void> updateCanteenInfo(
    CanteenAdminSession session, {
    required String name,
    required String phone,
    required String openingTime,
    required String closingTime,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/settings/canteen',
      method: 'PUT',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'name': name,
        'phone': phone,
        'openingTime': openingTime,
        'closingTime': closingTime,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> updateProfile(
    CanteenAdminSession session, {
    required String name,
    required String email,
    String? imageUrl,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/settings/profile',
      method: 'PUT',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'name': name,
        'email': email,
        'imageUrl': imageUrl,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> changePassword(
    CanteenAdminSession session, {
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/settings/change-password',
      method: 'POST',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );

    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> getMaintenance(CanteenAdminSession session) async {
    final response = await _authRequest(
      session,
      'api/canteen/maintenance',
      queryParameters: <String, dynamic>{
        'canteenId': session.canteenId,
      },
    );
    return _extractData(response);
  }

  Future<void> updateSystemMaintenance(
    CanteenAdminSession session, {
    required bool isActive,
    required String message,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/maintenance/system',
      method: 'PUT',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'isActive': isActive,
        'message': message,
      },
    );

    _ensureSuccess(response);
  }

  Future<void> updateCanteenMaintenance(
    CanteenAdminSession session, {
    required bool isActive,
    required String reason,
  }) async {
    final response = await _authRequest(
      session,
      'api/canteen/maintenance/canteen',
      method: 'PUT',
      data: <String, dynamic>{
        'canteenId': session.canteenId,
        'isActive': isActive,
        'reason': reason,
      },
    );

    _ensureSuccess(response);
  }

  Future<dynamic> _authRequest(
    CanteenAdminSession session,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return _apiClient.request(
      path,
      method: method,
      queryParameters: queryParameters,
      data: data,
      authenticated: true,
      bearerTokenOverride: session.token,
      headers: <String, dynamic>{
        'X-Requester-Email': session.email,
        'X-Requester-Role': session.role,
        ...?headers,
      },
    );
  }

  Map<String, dynamic> _extractData(dynamic response) {
    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Request failed.').toString());
    }
    return _asMap(body['data']);
  }

  void _ensureSuccess(dynamic response) {
    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Request failed.').toString());
    }
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asListOfMap(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
