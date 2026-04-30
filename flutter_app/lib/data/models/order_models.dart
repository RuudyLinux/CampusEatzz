class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    required this.itemCount,
  });

  final int id;
  final String orderNumber;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final DateTime? createdAt;
  final int itemCount;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: _asInt(json['id']),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      subtotal: _asDouble(json['subtotal']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      itemCount: _asInt(json['itemCount']),
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.imageUrl,
  });

  final int id;
  final int menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String imageUrl;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _asInt(json['id']),
      menuItemId: _asInt(json['menuItemId']),
      itemName: (json['itemName'] ?? '').toString(),
      quantity: _asInt(json['quantity']),
      unitPrice: _asDouble(json['unitPrice']),
      totalPrice: _asDouble(json['totalPrice']),
      imageUrl: (json['imageUrl'] ?? '').toString(),
    );
  }
}

class OrderStatusHistory {
  const OrderStatusHistory({
    required this.status,
    required this.createdAt,
  });

  final String status;
  final DateTime? createdAt;

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      status: (json['status'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
    );
  }
}

class OrderDetails {
  const OrderDetails({
    required this.id,
    required this.orderNumber,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.statusHistory,
  });

  final int id;
  final String orderNumber;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] is List) ? (json['items'] as List) : const [];
    final statusRaw = (json['statusHistory'] is List) ? (json['statusHistory'] as List) : const [];

    return OrderDetails(
      id: _asInt(json['id']),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      subtotal: _asDouble(json['subtotal']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(growable: false),
      statusHistory: statusRaw
          .whereType<Map<String, dynamic>>()
          .map(OrderStatusHistory.fromJson)
          .toList(growable: false),
    );
  }
}

class PlaceOrderResult {
  const PlaceOrderResult({
    required this.id,
    required this.orderNumber,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.walletBalance,
  });

  final int id;
  final String orderNumber;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final DateTime? createdAt;
  final double? walletBalance;

  factory PlaceOrderResult.fromJson(Map<String, dynamic> json) {
    return PlaceOrderResult(
      id: _asInt(json['id']),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      subtotal: _asDouble(json['subtotal']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      walletBalance: json['walletBalance'] == null ? null : _asDouble(json['walletBalance']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '0').toString()) ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    final raw = value.trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    if (parsed.isUtc) {
      return parsed;
    }
    // Server dates are UTC but often serialized without timezone info.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
  return null;
}
