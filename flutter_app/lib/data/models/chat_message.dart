class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: (json['role'] as String? ?? 'user').toLowerCase(),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  final String role;
  final String content;
  final DateTime timestamp;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
