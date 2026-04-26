class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.canteenId,
    required this.canteenName,
    required this.category,
    required this.reason,
    required this.orderCount,
    required this.isAvailable,
    this.spiceLevel = '',
    this.preparationTime = 0,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      RecommendationItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['imageUrl'] as String? ?? '',
        canteenId: (json['canteenId'] as num?)?.toInt() ?? 0,
        canteenName: json['canteenName'] as String? ?? '',
        category: json['category'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        isAvailable: json['isAvailable'] as bool? ?? true,
        spiceLevel: json['spiceLevel'] as String? ?? '',
        preparationTime: (json['preparationTime'] as num?)?.toInt() ?? 0,
      );

  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final int canteenId;
  final String canteenName;
  final String category;
  final String reason;
  final int orderCount;
  final bool isAvailable;
  final String spiceLevel;
  final int preparationTime;
}

class RecommendationSection {
  const RecommendationSection({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  factory RecommendationSection.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final rawItems = data['items'] is List ? (data['items'] as List) : const [];
    return RecommendationSection(
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      items: rawItems
          .whereType<Map>()
          .map((e) => RecommendationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }

  final String type;
  final String title;
  final String subtitle;
  final List<RecommendationItem> items;
}
