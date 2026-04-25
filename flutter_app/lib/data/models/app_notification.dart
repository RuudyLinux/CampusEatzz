class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.deliveryStatus,
    required this.isRead,
    required this.createdAtUtc,
    required this.data,
    this.readAtUtc,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String deliveryStatus;
  final bool isRead;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;
  final Map<String, String> data;

  NotificationAction? get action => NotificationAction.fromData(data);

  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? message,
    String? deliveryStatus,
    bool? isRead,
    DateTime? createdAtUtc,
    DateTime? readAtUtc,
    Map<String, String>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      readAtUtc: readAtUtc ?? this.readAtUtc,
      data: data ?? this.data,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']),
      type: (json['type'] ?? json['notificationType'] ?? 'general_alert').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      deliveryStatus: (json['deliveryStatus'] ?? 'pending').toString(),
      isRead: _asBool(json['isRead']),
      createdAtUtc: _asDateTime(json['createdAtUtc']) ?? DateTime.now().toUtc(),
      readAtUtc: _asDateTime(json['readAtUtc']),
      data: _asStringMap(json['data']),
    );
  }
}

class NotificationAction {
  const NotificationAction({
    required this.action,
    this.orderRef,
    this.orderId,
    this.canteenId,
  });

  final String action;
  final String? orderRef;
  final int? orderId;
  final int? canteenId;

  factory NotificationAction.fromData(Map<String, String> data) {
    final rawAction = (data['action'] ?? '').trim().toLowerCase();
    final normalizedAction = rawAction.isEmpty ? 'home' : rawAction;

    return NotificationAction(
      action: normalizedAction,
      orderRef: _emptyToNull(data['orderRef']),
      orderId: _asNullableInt(data['orderId']),
      canteenId: _asNullableInt(data['canteenId']),
    );
  }
}

Map<String, String> _asStringMap(dynamic value) {
  if (value is Map<String, String>) {
    return Map<String, String>.from(value);
  }

  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), (val ?? '').toString()));
  }

  return <String, String>{};
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

DateTime? _asDateTime(dynamic value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(text);
  return parsed?.toUtc();
}

String? _emptyToNull(String? value) {
  final normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}
