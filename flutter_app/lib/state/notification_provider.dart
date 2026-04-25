import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/app_notification.dart';
import '../data/models/user_session.dart';
import '../data/services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._service);

  final PushNotificationService _service;

  UserSession? _session;
  StreamSubscription<PushMessageEvent>? _pushSubscription;
  Timer? _pollTimer;

  List<AppNotification> _notifications = const <AppNotification>[];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  PushMessageEvent? _foregroundEvent;
  NotificationAction? _pendingAction;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get error => _error;

  void syncSession(UserSession? session) {
    final current = _session;
    if (current?.id == session?.id && current?.token == session?.token) {
      return;
    }

    _session = session;
    _error = null;

    if (session == null || session.token.trim().isEmpty) {
      _resetState();
      notifyListeners();
      return;
    }

    _startForSession(session);
  }

  Future<void> loadHistory({
    int limit = 40,
    bool unreadOnly = false,
    bool showLoading = true,
  }) async {
    final session = _session;
    if (session == null) {
      return;
    }

    if (showLoading) {
      _loading = true;
      notifyListeners();
    }

    try {
      _notifications = await _service.fetchHistory(
        session,
        limit: limit,
        unreadOnly: unreadOnly,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (showLoading) {
        _loading = false;
      }
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    final session = _session;
    if (session == null) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    try {
      _unreadCount = await _service.fetchUnreadCount(session);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final session = _session;
    if (session == null || notificationId <= 0) {
      return;
    }

    try {
      await _service.markRead(session, notificationId);

      _notifications = _notifications.map((item) {
        if (item.id == notificationId && !item.isRead) {
          return item.copyWith(isRead: true, readAtUtc: DateTime.now().toUtc());
        }
        return item;
      }).toList(growable: false);

      if (_unreadCount > 0) {
        _unreadCount -= 1;
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  PushMessageEvent? consumeForegroundEvent() {
    final event = _foregroundEvent;
    _foregroundEvent = null;
    return event;
  }

  NotificationAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  void _startForSession(UserSession session) {
    _pollTimer?.cancel();

    _pushSubscription ??= _service.events.listen((event) {
      if (event.openedFromTap) {
        _pendingAction = event.action;
      } else {
        _foregroundEvent = event;
      }

      unawaited(refreshUnreadCount());
      unawaited(loadHistory(limit: 20, showLoading: false));
      notifyListeners();
    });

    unawaited(_bootstrap(session));

    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(refreshUnreadCount());
    });
  }

  Future<void> _bootstrap(UserSession session) async {
    await _service.syncDeviceToken(session);
    await Future.wait<void>(<Future<void>>[
      loadHistory(limit: 40),
      refreshUnreadCount(),
    ]);
  }

  void _resetState() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _notifications = const <AppNotification>[];
    _unreadCount = 0;
    _loading = false;
    _foregroundEvent = null;
    _pendingAction = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
