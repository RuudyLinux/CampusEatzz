import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/network_food_image.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/order_models.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../auth/login_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.orderRef});

  final String orderRef;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().session;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        body: Column(
          children: <Widget>[
            const GradientHeader(title: 'Order Details', showLogo: false),
            Expanded(
              child: AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Login Required',
                subtitle: 'Please sign in to view order details.',
                actionLabel: 'Sign In',
                onAction: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'Order Details',
            subtitle: 'Order #$orderRef',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: FutureBuilder<OrderDetails>(
              future: context.read<OrdersProvider>().loadOrderDetails(
                    identifier: user.identifier,
                    orderRef: orderRef,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonScreen(itemCount: 6);
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return AppEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Failed to Load',
                    subtitle: snapshot.error?.toString() ??
                        'Unable to load order details.',
                    iconColor: Theme.of(context).colorScheme.error,
                  );
                }

                final order = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: <Widget>[
                    // Order info card
                    AnimatedReveal(
                      delayMs: 60,
                      child: _SectionCard(
                        title: 'Order Info',
                        isDark: isDark,
                        child: Column(
                          children: <Widget>[
                            _InfoRow(
                                label: 'Order Number',
                                value: order.orderNumber,
                                isDark: isDark),
                            _InfoRow(
                                label: 'Date',
                                value: formatDateTime(order.createdAt),
                                isDark: isDark),
                            _InfoRow(
                              label: 'Order Status',
                              isDark: isDark,
                              valueWidget: AppStatusBadge.fromString(
                                  order.status,
                                  small: true),
                            ),
                            _InfoRow(
                              label: 'Payment',
                              isDark: isDark,
                              valueWidget: AppStatusBadge.fromString(
                                  order.paymentStatus,
                                  small: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items card
                    AnimatedReveal(
                      delayMs: 120,
                      child: _SectionCard(
                        title: 'Ordered Items',
                        isDark: isDark,
                        child: Column(
                          children: order.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.imageUrl.isNotEmpty
                                        ? NetworkFoodImage(
                                            imageUrl: item.imageUrl,
                                            fallbackAsset:
                                                'assets/images/Restaurants.jpg',
                                            foodName: item.itemName,
                                            width: 48,
                                            height: 48,
                                            borderRadius: BorderRadius.zero,
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: isDark
                                                ? AppColors.darkSurface
                                                : AppColors.bgSoft,
                                            child: Icon(
                                              Icons.fastfood_rounded,
                                              size: 22,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          item.itemName,
                                          style: AppTypography.label.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '× ${item.quantity}',
                                          style: AppTypography.caption
                                              .copyWith(
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatInr(item.totalPrice),
                                    style: AppTypography.priceSm.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Summary card
                    AnimatedReveal(
                      delayMs: 180,
                      child: _SectionCard(
                        title: 'Summary',
                        isDark: isDark,
                        child: Column(
                          children: <Widget>[
                            _InfoRow(
                                label: 'Subtotal',
                                value: formatInr(order.subtotal),
                                isDark: isDark),
                            _InfoRow(
                                label: 'Tax',
                                value: formatInr(order.tax),
                                isDark: isDark),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                color: isDark
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                              ),
                            ),
                            _InfoRow(
                                label: 'Total',
                                value: formatInr(order.total),
                                isDark: isDark,
                                bold: true),
                          ],
                        ),
                      ),
                    ),

                    // Status history
                    if (order.statusHistory.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      AnimatedReveal(
                        delayMs: 240,
                        child: _SectionCard(
                          title: 'Status History',
                          isDark: isDark,
                          child: Column(
                            children: order.statusHistory.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.primaryOnDark
                                            : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        titleCase(entry.status),
                                        style: AppTypography.body.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatDateTime(entry.createdAt),
                                      style: AppTypography.caption.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.isDark,
    required this.child,
  });

  final String title;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.isDark,
    this.value,
    this.valueWidget,
    this.bold = false,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool isDark;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.body.copyWith(
      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
    );
    final valueStyle = (bold ? AppTypography.heading3 : AppTypography.label)
        .copyWith(
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(label, style: labelStyle),
          const Spacer(),
          valueWidget ?? Text(value ?? '', style: valueStyle),
        ],
      ),
    );
  }
}
