import '../models/chat_message.dart';
import 'api_client.dart';

class ChatService {
  ChatService(this._apiClient);

  final ApiClient _apiClient;

  Future<String> sendMessage({
    required String sessionId,
    required String message,
    int? userId,
  }) async {
    final response = await _apiClient.request(
      'api/chat/message',
      method: 'POST',
      authenticated: false,
      data: <String, dynamic>{
        'sessionId': sessionId,
        'message': message,
        if (userId != null && userId > 0) 'userId': userId,
      },
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Failed to send message').toString());
    }

    final data = _asMap(body['data']);
    return data['response'] as String? ?? '';
  }

  Future<List<ChatMessage>> fetchHistory(String sessionId, {int limit = 50}) async {
    final response = await _apiClient.request(
      'api/chat/history/$sessionId',
      method: 'GET',
      authenticated: false,
      queryParameters: <String, dynamic>{'limit': limit},
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      return const [];
    }

    final data = _asMap(body['data']);
    final messages = (data['messages'] is List) ? (data['messages'] as List) : const [];
    return messages
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}
