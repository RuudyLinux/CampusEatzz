import '../models/chat_message.dart';
import 'api_client.dart';

class ChatService {
  ChatService(this._apiClient);

  final ApiClient _apiClient;

  Future<ChatResponse> sendMessage({
    required String sessionId,
    required String message,
    int? userId,
    String? userName,
  }) async {
    final response = await _apiClient.request(
      'api/chat/message',
      method: 'POST',
      authenticated: false,
      data: <String, dynamic>{
        'sessionId': sessionId,
        'message': message,
        if (userId != null && userId > 0) 'userId': userId,
        if (userName != null && userName.trim().isNotEmpty) 'userName': userName.trim(),
      },
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception((body['message'] ?? 'Failed to send message').toString());
    }

    final data = _asMap(body['data']);
    return ChatResponse.fromJson(data);
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

class ChatResponse {
  const ChatResponse({
    required this.response,
    this.intent,
    this.action,
    this.canteenId,
    this.canteenName,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] as String? ?? '',
      intent: json['intent'] as String?,
      action: json['action'] as String?,
      canteenId: _asInt(json['canteenId']),
      canteenName: json['canteenName'] as String?,
    );
  }

  final String response;
  final String? intent;
  final String? action;
  final int? canteenId;
  final String? canteenName;

  bool get shouldShowMenu => action == 'show_menu';
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  final parsed = int.tryParse((value ?? '').toString());
  return parsed != null && parsed > 0 ? parsed : null;
}
