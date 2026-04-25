import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../core/widgets/gradient_header.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.profile),
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'Notifications',
            subtitle: state.unreadCount > 0
                ? '${state.unreadCount} unread updates'
                : 'All caught up',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await state.loadHistory(limit: 50);
                await state.refreshUnreadCount();
              },
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.notifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.notifications.isEmpty) {
                    return ListView(
                      children: const <Widget>[
                        SizedBox(height: 60),
                        AppEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No Notifications Yet',
                          subtitle: 'Order updates and alerts will appear here.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = state.notifications[index];
                      return _NotificationCard(
                        item: item,
                        isDark: isDark,
                        onTap: () async {
                          if (!item.isRead) {
                            await state.markAsRead(item.id);
                          }

                          final action = item.action;
                          if (action != null && context.mounted) {
                            await NotificationNavigation.openAction(context, action);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final AppNotification item;
  final bool isDark;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      'order_update' => Icons.receipt_long_rounded,
      'offer' => Icons.local_offer_rounded,
      'promotion' => Icons.campaign_rounded,
      _ => Icons.notifications_active_rounded,
    };

    final iconColor = switch (item.type) {
      'order_update' => AppColors.tabHome,
      'offer' => AppColors.tabWallet,
      'promotion' => AppColors.tabCart,
      _ => AppColors.primary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? (isDark ? AppColors.darkBorder : AppColors.border)
                  : iconColor.withValues(alpha: 0.50),
              width: item.isRead ? 1 : 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.navy.withValues(alpha: isDark ? 0.22 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTypography.label.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: AppTypography.bodySm.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatDate(item.createdAtUtc.toLocal()),
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
