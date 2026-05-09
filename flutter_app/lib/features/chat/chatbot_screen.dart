import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/gradient_header.dart';
import '../../data/models/chat_message.dart';
import '../../state/auth_provider.dart';
import '../../state/canteen_provider.dart';
import '../../state/chat_provider.dart';
import '../menu/menu_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> _suggestedQueries = <String>[
    'Suggest food under ₹100',
    'What\'s popular today?',
    'Show menu from Foodies',
    'Recommend something tasty',
    'Budget meals under ₹150',
    'What\'s available at Chirag Tea Center?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ChatProvider>().loadHistory(userId: auth.session?.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    final auth = context.read<AuthProvider>();
    final response = await context.read<ChatProvider>().sendMessage(
          text,
          userId: auth.session?.id,
          userName: auth.session?.name,
        );
    _scrollToBottom();
    if (!mounted || response == null) return;
  }

  Future<void> _openMenuFromChat(ChatMessage message) async {
    final canteenProvider = context.read<CanteenProvider>();
    if (canteenProvider.canteens.isEmpty) {
      await canteenProvider.loadCanteens();
      if (!mounted) return;
    }

    final normalizedCanteenName = message.canteenName?.trim().toLowerCase();
    final canteen = message.canteenId != null
        ? canteenProvider.canteens
            .where((item) => item.id == message.canteenId)
            .firstOrNull
        : normalizedCanteenName?.isNotEmpty == true
            ? canteenProvider.canteens
                .where((item) =>
                    item.name.trim().toLowerCase() == normalizedCanteenName)
                .firstOrNull
            : (canteenProvider.canteens.isNotEmpty
                ? canteenProvider.canteens.first
                : null);

    if (canteen == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MenuScreen(
          canteenId: canteen.id,
          canteenName: message.canteenName?.trim().isNotEmpty == true
              ? message.canteenName
              : canteen.name,
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text('This will delete all messages in this session.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ChatProvider>().clearChat();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = context.watch<ChatProvider>();

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'CampusEatzz AI',
            subtitle: chatState.isSending
                ? 'Typing...'
                : 'Ask me anything about food',
            showLogo: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (chatState.hasMessages)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                    tooltip: 'Clear chat',
                    onPressed: () => _confirmClear(context),
                  ),
                IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: chatState.messages.isEmpty
                ? _WelcomeView(
                    isDark: isDark,
                    onSuggestion: _send,
                    suggestions: _suggestedQueries,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: chatState.messages.length +
                        (chatState.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = chatState.messages[index];
                      return _MessageBubble(
                        message: msg,
                        isDark: isDark,
                        onAction: _openMenuFromChat,
                      );
                    },
                  ),
          ),
          if (chatState.messages.isNotEmpty && !chatState.isSending)
            _SuggestionsBar(
              suggestions: _suggestedQueries.take(3).toList(),
              onTap: _send,
              isDark: isDark,
            ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isSending: chatState.isSending,
            isDark: isDark,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Welcome screen shown when chat is empty ───────────────────────────────────

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.isDark,
    required this.onSuggestion,
    required this.suggestions,
  });

  final bool isDark;
  final void Function(String) onSuggestion;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        children: <Widget>[
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.darkHeaderGradient
                  : AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CampusEatzz AI',
            style: AppTypography.heading2.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about food, recommendations, or our canteens!',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking...',
              style: AppTypography.label.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionTile(
                query: q,
                isDark: isDark,
                onTap: onSuggestion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.query,
    required this.isDark,
    required this.onTap,
  });

  final String query;
  final bool isDark;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => onTap(query),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: isDark ? AppColors.primaryOnDark : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  query,
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.onAction,
  });

  final ChatMessage message;
  final bool isDark;
  final Future<void> Function(ChatMessage message) onAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.darkHeaderGradient
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.content,
                    style: AppTypography.body.copyWith(
                      color: isUser
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                      height: 1.45,
                    ),
                  ),
                  if (message.shouldShowMenuAction) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => onAction(message),
                        icon:
                            const Icon(Icons.restaurant_menu_rounded, size: 18),
                        label: const Text('Order this'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: AppTypography.label,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...<Widget>[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 6, bottom: 2),
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.darkCardRaised : AppColors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing indicator (three animated dots) ───────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.darkHeaderGradient
                  : AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(3, (i) {
                    final delay = i * 0.3;
                    final value = (_controller.value - delay) % 1.0;
                    final opacity = value < 0.5 ? value * 2 : (1.0 - value) * 2;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity.clamp(0.2, 1.0),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick suggestion chips shown above input ──────────────────────────────────

class _SuggestionsBar extends StatelessWidget {
  const _SuggestionsBar({
    required this.suggestions,
    required this.onTap,
    required this.isDark,
  });

  final List<String> suggestions;
  final void Function(String) onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => onTap(suggestions[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                suggestions[i],
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isDark,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isDark;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isSending,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about food, menu, prices...',
                  hintStyle: AppTypography.body.copyWith(
                    color:
                        isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  isDense: true,
                ),
                onSubmitted: isSending ? null : onSend,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSending ? null : () => onSend(controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSending
                    ? (isDark ? AppColors.darkCard : AppColors.surfaceRaised)
                    : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: isSending
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: Icon(
                  isSending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  color: isSending
                      ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                      : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
