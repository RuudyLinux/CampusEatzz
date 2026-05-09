import 'dart:math';
import 'package:flutter/foundation.dart';

import '../data/models/chat_message.dart';
import '../data/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._chatService);

  final ChatService _chatService;

  final List<ChatMessage> _messages = [];
  String _sessionId = _generateSessionId();
  bool _isSending = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get sessionId => _sessionId;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasMessages => _messages.isNotEmpty;

  Future<ChatResponse?> sendMessage(String text, {int? userId, String? userName}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return null;

    // Optimistically add user message
    _messages.add(ChatMessage(
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    ));
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _chatService.sendMessage(
        sessionId: _sessionId,
        message: trimmed,
        userId: userId,
        userName: userName,
      );

      _messages.add(ChatMessage(
        role: 'assistant',
        content: response.response,
        timestamp: DateTime.now(),
      ));
      _error = null;
      return response;
    } catch (e) {
      _error = 'Failed to get response. Please try again.';
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: DateTime.now(),
      ));
    } finally {
      _isSending = false;
      notifyListeners();
    }

    return null;
  }

  Future<void> loadHistory({int? userId}) async {
    try {
      final history = await _chatService.fetchHistory(_sessionId);
      if (history.isNotEmpty) {
        _messages.clear();
        _messages.addAll(history);
        notifyListeners();
      }
    } catch (_) {
      // Ignore history load failure — start fresh
    }
  }

  void clearChat() {
    _messages.clear();
    _sessionId = _generateSessionId();
    _error = null;
    notifyListeners();
  }

  static String _generateSessionId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
