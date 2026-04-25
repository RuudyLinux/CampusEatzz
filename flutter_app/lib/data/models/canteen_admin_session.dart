class CanteenAdminSession {
  const CanteenAdminSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.canteenId,
    required this.canteenName,
    required this.token,
    this.imageUrl = '',
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int canteenId;
  final String canteenName;
  final String token;
  final String imageUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'canteenId': canteenId,
      'canteenName': canteenName,
      'token': token,
      'imageUrl': imageUrl,
    };
  }

  factory CanteenAdminSession.fromJson(Map<String, dynamic> json) {
    return CanteenAdminSession(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'canteen_admin').toString(),
      canteenId: _asInt(json['canteenId']),
      canteenName: (json['canteenName'] ?? 'Canteen').toString(),
      token: (json['token'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
    );
  }

  CanteenAdminSession copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    int? canteenId,
    String? canteenName,
    String? token,
    String? imageUrl,
  }) {
    return CanteenAdminSession(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      canteenId: canteenId ?? this.canteenId,
      canteenName: canteenName ?? this.canteenName,
      token: token ?? this.token,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
