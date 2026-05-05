class UserSession {
  const UserSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.universityId,
    required this.token,
    this.firstName = '',
    this.lastName = '',
    this.contact = '',
    this.department = '',
    this.profileImageUrl = '',
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String universityId;
  final String token;
  final String firstName;
  final String lastName;
  final String contact;
  final String department;
  final String profileImageUrl;

  String get identifier {
    if (universityId.trim().isNotEmpty) {
      return universityId.trim();
    }
    if (email.trim().isNotEmpty) {
      return email.trim();
    }
    return id.toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'universityId': universityId,
      'token': token,
      'firstName': firstName,
      'lastName': lastName,
      'contact': contact,
      'department': department,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      universityId: (json['universityId'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      profileImageUrl: (json['profileImageUrl'] ?? '').toString(),
    );
  }

  UserSession copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? universityId,
    String? token,
    String? firstName,
    String? lastName,
    String? contact,
    String? department,
    String? profileImageUrl,
  }) {
    return UserSession(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      universityId: universityId ?? this.universityId,
      token: token ?? this.token,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      contact: contact ?? this.contact,
      department: department ?? this.department,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
