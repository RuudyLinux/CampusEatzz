class Canteen {
  const Canteen({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.status,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final String status;

  factory Canteen.fromJson(Map<String, dynamic> json) {
    return Canteen(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
