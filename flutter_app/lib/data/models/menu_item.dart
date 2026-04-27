class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.isAvailable,
    required this.isVegetarian,
    required this.canteenId,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool isAvailable;
  final bool isVegetarian;
  final int canteenId;

  factory MenuItem.fromJson(Map<String, dynamic> json, {required int canteenId}) {
    return MenuItem(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _asDouble(json['price']),
      category: (json['category'] ?? 'Uncategorized').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? json['image'] ?? '').toString(),
      isAvailable: _asBool(json['isAvailable'], fallback: true),
      isVegetarian: _asBool(json['isVegetarian']),
      canteenId: canteenId,
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

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1') {
      return true;
    }
    if (v == 'false' || v == '0') {
      return false;
    }
  }
  return fallback;
}
