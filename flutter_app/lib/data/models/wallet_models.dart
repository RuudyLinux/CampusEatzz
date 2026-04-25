class WalletInfo {
  const WalletInfo({
    required this.balance,
    required this.currency,
  });

  final double balance;
  final String currency;

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: _asDouble(json['balance']),
      currency: (json['currency'] ?? 'INR').toString(),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    required this.orderId,
    required this.createdAt,
  });

  final int id;
  final String transactionId;
  final double amount;
  final String type;
  final String status;
  final String description;
  final int? orderId;
  final DateTime? createdAt;

  bool get isCredit => type.toLowerCase() == 'credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: _asInt(json['id']),
      transactionId: (json['transactionId'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      orderId: _optionalInt(json['orderId']),
      createdAt: _toDate(json['createdAt']),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '0').toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

int? _optionalInt(dynamic value) {
  final parsed = int.tryParse((value ?? '').toString());
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

DateTime? _toDate(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
