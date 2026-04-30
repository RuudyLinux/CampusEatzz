class RefundInfo {
  const RefundInfo({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.adminNotes,
  });

  final int id;
  final int orderId;
  final double amount;
  final String reason;
  final String status; // pending, approved, rejected
  final DateTime? createdAt;
  final DateTime? processedAt;
  final String? adminNotes;

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

  factory RefundInfo.fromJson(Map<String, dynamic> json) {
    return RefundInfo(
      id: _asInt(json['refundId']),
      orderId: _asInt(json['orderId']),
      amount: _asDouble(json['amount']),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      processedAt: _toDate(json['processedAt']),
      adminNotes: json['adminNotes']?.toString(),
    );
  }
}

class RequestRefundResult {
  const RequestRefundResult({
    required this.refundId,
    required this.orderId,
    required this.amount,
    required this.status,
    this.walletBalance,
  });

  final int refundId;
  final int orderId;
  final double amount;
  final String status;
  final double? walletBalance;

  factory RequestRefundResult.fromJson(Map<String, dynamic> json) {
    return RequestRefundResult(
      refundId: _asInt(json['refundId']),
      orderId: _asInt(json['orderId']),
      amount: _asDouble(json['amount']),
      status: (json['status'] ?? '').toString(),
      walletBalance: json['walletBalance'] == null ? null : _asDouble(json['walletBalance']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '0').toString()) ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
