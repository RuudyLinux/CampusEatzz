import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';
import '../models/user_session.dart';
import 'api_client.dart';

class PushMessageEvent {
  const PushMessageEvent({
    required this.title,
    required this.body,
    required this.data,
    required this.openedFromTap,
  });

  final String title;
  final String body;
  final Map<String, String> data;
  final bool openedFromTap;

  NotificationAction get action => NotificationAction.fromData(data);
}

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<PushMessageEvent> _eventsController =
      StreamController<PushMessageEvent>.broadcast();

  Stream<PushMessageEvent> get events => _eventsController.stream;

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _firebaseReady = true;

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        _emit(message, openedFromTap: false);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _emit(message, openedFromTap: true);
      });

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _emit(initial, openedFromTap: true);
      }
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<void> syncDeviceToken(UserSession session) async {
    await initialize();

    if (!_firebaseReady) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _registerDeviceToken(session, token);
      _lastRegisteredToken = token;

      _tokenRefreshSubscription ??=
          FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
        final normalized = nextToken.trim();
        if (normalized.isEmpty || normalized == _lastRegisteredToken) {
          return;
        }

        await _registerDeviceToken(session, normalized);
        _lastRegisteredToken = normalized;
      });
    } catch (_) {
      // The app still works with polling-only notifications when token sync fails.
    }
  }

  Future<List<AppNotification>> fetchHistory(
    UserSession session, {
    int limit = 40,
    bool unreadOnly = false,
  }) async {
    final response = await _apiClient.request(
      'api/notifications/history',
      method: 'GET',
      bearerTokenOverride: session.token,
      queryParameters: <String, dynamic>{
        'limit': limit,
        'unreadOnly': unreadOnly,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load notifications.');

    final data = _asMap(body['data']);
    final rows = (data['notifications'] is List) ? (data['notifications'] as List) : const <dynamic>[];

    return rows
        .whereType<Map>()
        .map((raw) => AppNotification.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount(UserSession session) async {
    final response = await _apiClient.request(
      'api/notifications/unread-count',
      method: 'GET',
      bearerTokenOverride: session.token,
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to load unread count.');

    final data = _asMap(body['data']);
    return _asInt(data['unreadCount']);
  }

  Future<void> markRead(UserSession session, int notificationId) async {
    final response = await _apiClient.request(
      'api/notifications/mark-read',
      method: 'POST',
      bearerTokenOverride: session.token,
      data: <String, dynamic>{
        'notificationId': notificationId,
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to update notification.');
  }

  Future<void> _registerDeviceToken(UserSession session, String token) async {
    final response = await _apiClient.request(
      'api/notifications/device-token',
      method: 'POST',
      bearerTokenOverride: session.token,
      data: <String, dynamic>{
        'token': token,
        'platform': 'android',
      },
    );

    final body = _asMap(response.data);
    _ensureSuccess(body, fallback: 'Unable to register device token.');
  }

  void _emit(RemoteMessage message, {required bool openedFromTap}) {
    final title = message.notification?.title ?? 'CampusEatzz Update';
    final body = message.notification?.body ?? 'You have a new notification.';
    final data = message.data.map((key, value) => MapEntry(key, value.toString()));

    _eventsController.add(PushMessageEvent(
      title: title,
      body: body,
      data: data,
      openedFromTap: openedFromTap,
    ));
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _eventsController.close();
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

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
