import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../data/models/app_notification.dart';
import '../../state/notification_provider.dart';
import 'notification_navigation.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadHistory(limit: 50);
    });
  }

  Future<void> _markAllRead() async {
    final state = context.read<NotificationProvider>();
    for (final n in state.notifications.where((n) => !n.isRead)) {
      await state.markAsRead(n.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final grouped = _groupByPeriod(state.notifications);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.profile),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 22,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activity',
                      style: AppTypography.display.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  if (state.unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await state.loadHistory(limit: 50);
                  await state.refreshUnreadCount();
                },
                child: Builder(builder: (context) {
                  if (state.isLoading && state.notifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.notifications.isEmpty) {
                    return ListView(
                      children: const <Widget>[
                        SizedBox(height: 60),
                        AppEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No Activity Yet',
                          subtitle:
                              'Order updates and alerts will appear here.',
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: <Widget>[
                      for (final entry in grouped.entries) ...<Widget>[
                        _PeriodHeader(label: entry.key, isDark: isDark),
                        // White card wrapping all items in this period
                        _NotificationGroup(
                          items: entry.value,
                          isDark: isDark,
                          onTap: (item) async {
                            if (!item.isRead) {
                              await state.markAsRead(item.id);
                            }
                            final action = item.action;
                            if (action != null && context.mounted) {
                              await NotificationNavigation.openAction(
                                  context, action);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups notifications into TODAY / THIS WEEK / EARLIER.
  Map<String, List<AppNotification>> _groupByPeriod(
      List<AppNotification> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final today = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final earlier = <AppNotification>[];

    for (final item in items) {
      final local = item.createdAtUtc.toLocal();
      if (!local.isBefore(todayStart)) {
        today.add(item);
      } else if (!local.isBefore(weekStart)) {
        thisWeek.add(item);
      } else {
        earlier.add(item);
      }
    }

    return <String, List<AppNotification>>{
      if (today.isNotEmpty) 'TODAY': today,
      if (thisWeek.isNotEmpty) 'THIS WEEK': thisWeek,
      if (earlier.isNotEmpty) 'EARLIER': earlier,
    };
  }
}

// ── Period Header ─────────────────────────────────────────────────────────────

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          letterSpacing: 1.0,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Notification Group Card ───────────────────────────────────────────────────

class _NotificationGroup extends StatelessWidget {
  const _NotificationGroup({
    required this.items,
    required this.isDark,
    required this.onTap,
  });

  final List<AppNotification> items;
  final bool isDark;
  final Future<void> Function(AppNotification) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List<Widget>.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return _NotificationRow(
            item: item,
            isDark: isDark,
            showDivider: !isLast,
            onTap: () => onTap(item),
          );
        }),
      ),
    );
  }
}

// ── Notification Row ──────────────────────────────────────────────────────────

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.isDark,
    required this.showDivider,
    required this.onTap,
  });

  final AppNotification item;
  final bool isDark;
  final bool showDivider;
  final VoidCallback onTap;

  static IconData _icon(String type) => switch (type) {
        'order_update' => Icons.shopping_bag_outlined,
        'offer' => Icons.local_offer_outlined,
        'promotion' => Icons.campaign_outlined,
        'wallet' => Icons.account_balance_wallet_outlined,
        _ => Icons.notifications_outlined,
      };

  static Color _iconColor(String type) => switch (type) {
        'order_update' => AppColors.primary,
        'offer' => Color(0xFFFF9800),
        'promotion' => AppColors.accent,
        'wallet' => Color(0xFF4CAF50),
        _ => AppColors.tabWallet,
      };

  @override
  Widget build(BuildContext context) {
    final iconColor = _iconColor(item.type);

    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(_icon(item.type), size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: AppTypography.label.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.message,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(item.createdAtUtc.toLocal()),
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 68,
            color: isDark
                ? AppColors.darkDivider
                : AppColors.divider.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}
