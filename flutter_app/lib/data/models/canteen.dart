class Canteen {
  const Canteen({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.status,
    this.isUnderMaintenance = false,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final String status;
  final bool isUnderMaintenance;

  /// True if status is "open" or "active" (backend uses both).
  bool get isOpen {
    final s = status.toLowerCase();
    return s == 'open' || s == 'active';
  }

  factory Canteen.fromJson(Map<String, dynamic> json) {
    return Canteen(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      isUnderMaintenance: _asBool(json['isUnderMaintenance'])
          || _asBool(json['maintenanceMode'])
          || _asBool(json['maintenance']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final s = (value ?? '').toString().toLowerCase();
  return s == 'true' || s == '1';
}
