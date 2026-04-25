import 'menu_item.dart';

class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.canteenId,
  });

  final int menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final int? canteenId;

  double get lineTotal => price * quantity;

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
      canteenId: canteenId,
    );
  }

  factory CartItem.fromMenu(MenuItem item) {
    return CartItem(
      menuItemId: item.id,
      name: item.name,
      price: item.price,
      quantity: 1,
      imageUrl: item.imageUrl,
      canteenId: item.canteenId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'canteenId': canteenId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItemId: _asInt(json['menuItemId'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      price: _asDouble(json['price'] ?? json['unitPrice']),
      quantity: _asInt(json['quantity'] ?? 1),
      imageUrl: (json['imageUrl'] ?? json['image'] ?? '').toString(),
      canteenId: _optionalInt(json['canteenId']),
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

int? _optionalInt(dynamic value) {
  final parsed = int.tryParse((value ?? '').toString());
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
