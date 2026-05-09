class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.intent,
    this.action,
    this.canteenId,
    this.canteenName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: (json['role'] as String? ?? 'user').toLowerCase(),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
        intent: json['intent'] as String?,
        action: json['action'] as String?,
        canteenId: _asInt(json['canteenId']),
        canteenName: json['canteenName'] as String?,
      );

  final String role;
  final String content;
  final DateTime timestamp;
  final String? intent;
  final String? action;
  final int? canteenId;
  final String? canteenName;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get shouldShowMenuAction => isAssistant && action == 'show_menu';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  final parsed = int.tryParse((value ?? '').toString());
  return parsed != null && parsed > 0 ? parsed : null;
}
