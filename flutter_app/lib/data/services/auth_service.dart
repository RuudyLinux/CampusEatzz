import '../models/auth_models.dart';
import '../models/user_session.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<OtpChallenge> requestOtp({
    required String identifier,
    required String password,
  }) async {
    final response = await _apiClient.request(
      'api/login.php',
      method: 'POST',
      data: <String, dynamic>{
        'email': identifier,
        'password': password,
      },
      authenticated: false,
    );

    final body = _asMap(response.data);
    final success = body['success'] == true;
    final data = _asMap(body['data']);

    final responseIdentifier = (data['identifier'] ?? '').toString().trim();

    return OtpChallenge(
      success: success,
      message: (body['message'] ?? 'Unable to request OTP').toString(),
      identifier: responseIdentifier.isNotEmpty ? responseIdentifier : identifier.trim(),
      developmentOtp: data['developmentOtp']?.toString(),
    );
  }

  Future<OtpChallenge> resendOtp(String identifier) async {
    final response = await _apiClient.request(
      'api/auth/resend-otp',
      method: 'POST',
      data: <String, dynamic>{
        'email': identifier,
      },
      authenticated: false,
    );

    final body = _asMap(response.data);
    final data = _asMap(body['data']);
    return OtpChallenge(
      success: body['success'] == true,
      message: (body['message'] ?? 'Unable to resend OTP').toString(),
      identifier: identifier,
      developmentOtp: data['developmentOtp']?.toString(),
    );
  }

  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    final response = await _apiClient.request(
      'api/auth/verify-otp',
      method: 'POST',
      data: <String, dynamic>{
        'email': identifier,
        'otp': otp,
      },
      authenticated: false,
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'OTP verification failed').toString());
    }

    final data = _asMap(body['data']);
    final token = (body['token'] ?? '').toString();

    return UserSession(
      id: _asInt(data['id']),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      universityId: (data['universityId'] ?? identifier).toString(),
      token: token,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      contact: (data['contact'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      profileImageUrl: (data['profileImageUrl'] ?? '').toString(),
    );
  }

  Future<UserSession> fetchMe(UserSession current) async {
    final response = await _apiClient.request(
      'api/auth/me',
      queryParameters: <String, dynamic>{
        'identifier': current.identifier,
      },
      authenticated: true,
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      return current;
    }

    final data = _asMap(body['data']);
    return current.copyWith(
      name: (data['name'] ?? current.name).toString(),
      email: (data['email'] ?? current.email).toString(),
      role: (data['role'] ?? current.role).toString(),
      universityId: (data['universityId'] ?? current.universityId).toString(),
      firstName: (data['firstName'] ?? current.firstName).toString(),
      lastName: (data['lastName'] ?? current.lastName).toString(),
      contact: (data['contact'] ?? current.contact).toString(),
      department: (data['department'] ?? current.department).toString(),
      profileImageUrl: data['profileImageUrl'] != null
          ? data['profileImageUrl'].toString()
          : current.profileImageUrl,
    );
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return <String, dynamic>{};
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}
