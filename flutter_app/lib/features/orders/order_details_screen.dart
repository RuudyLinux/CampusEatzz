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
import '../../data/models/refund_models.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/refund_provider.dart';
import '../auth/login_screen.dart';
import 'refund_request_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderRef});

  final String orderRef;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Future<OrderDetails> _orderFuture;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    final user = context.read<AuthProvider>().session;
    if (user == null) return;
    _orderFuture = context.read<OrdersProvider>().loadOrderDetails(
          identifier: user.identifier,
          orderRef: widget.orderRef,
        );
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
      _loadOrder();
    });
  }

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
            subtitle: 'Order #${widget.orderRef}',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: FutureBuilder<OrderDetails>(
              key: ValueKey(_refreshKey),
              future: _orderFuture,
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
                return _OrderBody(
                  order: order,
                  isDark: isDark,
                  userIdentifier: user.identifier,
                  onRefundSubmitted: _refresh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    required this.isDark,
    required this.userIdentifier,
    required this.onRefundSubmitted,
  });

  final OrderDetails order;
  final bool isDark;
  final String userIdentifier;
  final VoidCallback onRefundSubmitted;

  bool get _refundEligible =>
      order.status.toLowerCase() == 'cancelled' &&
      order.paymentStatus.toLowerCase() == 'paid';

  bool get _alreadyRefunded =>
      order.paymentStatus.toLowerCase() == 'refunded';

  @override
  Widget build(BuildContext context) {
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
                  valueWidget:
                      AppStatusBadge.fromString(order.status, small: true),
                ),
                _InfoRow(
                  label: 'Payment',
                  isDark: isDark,
                  valueWidget: AppStatusBadge.fromString(order.paymentStatus,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              style: AppTypography.caption.copyWith(
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
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

        // Refund section
        const SizedBox(height: 12),
        AnimatedReveal(
          delayMs: 300,
          child: _alreadyRefunded
              ? _RefundedBanner(isDark: isDark, total: order.total)
              : _refundEligible
                  ? _RefundSection(
                      order: order,
                      isDark: isDark,
                      userIdentifier: userIdentifier,
                      onRefundSubmitted: onRefundSubmitted,
                    )
                  : const SizedBox.shrink(),
        ),

        // Existing refund status (if pending/rejected)
        if (!_alreadyRefunded && !_refundEligible)
          _ExistingRefundStatus(
            orderRef: order.orderNumber,
            userIdentifier: userIdentifier,
            isDark: isDark,
          ),
      ],
    );
  }
}

// ── Refund widgets ─────────────────────────────────────────────────────────────

class _RefundedBanner extends StatelessWidget {
  const _RefundedBanner({required this.isDark, required this.total});

  final bool isDark;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.successBgDark : AppColors.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Refund Processed',
                  style: AppTypography.label
                      .copyWith(color: AppColors.success),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatInr(total)} has been credited to your wallet.',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.success.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundSection extends StatelessWidget {
  const _RefundSection({
    required this.order,
    required this.isDark,
    required this.userIdentifier,
    required this.onRefundSubmitted,
  });

  final OrderDetails order;
  final bool isDark;
  final String userIdentifier;
  final VoidCallback onRefundSubmitted;

  @override
  Widget build(BuildContext context) {
    return _ExistingRefundStatus(
      orderRef: order.orderNumber,
      userIdentifier: userIdentifier,
      isDark: isDark,
      fallback: _RefundPromptCard(
        order: order,
        isDark: isDark,
        onRefundSubmitted: onRefundSubmitted,
      ),
    );
  }
}

class _RefundPromptCard extends StatelessWidget {
  const _RefundPromptCard({
    required this.order,
    required this.isDark,
    required this.onRefundSubmitted,
  });

  final OrderDetails order;
  final bool isDark;
  final VoidCallback onRefundSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warningBgDark : AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Eligible for Refund',
                style: AppTypography.label
                    .copyWith(color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This order was cancelled. You can request a refund of ${formatInr(order.total)}.',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => RefundRequestScreen(order: order),
                  ),
                );
                if (result == true) {
                  onRefundSubmitted();
                }
              },
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Request Refund'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.primaryOnDark : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingRefundStatus extends StatelessWidget {
  const _ExistingRefundStatus({
    required this.orderRef,
    required this.userIdentifier,
    required this.isDark,
    this.fallback,
  });

  final String orderRef;
  final String userIdentifier;
  final bool isDark;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RefundInfo?>(
      future: context.read<RefundProvider>().getRefundStatus(
            identifier: userIdentifier,
            orderRef: orderRef,
          ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final refund = snap.data;
        if (refund == null) return fallback ?? const SizedBox.shrink();

        Color bgColor;
        Color iconColor;
        IconData icon;
        String title;
        String subtitle;

        if (refund.isApproved) {
          bgColor =
              isDark ? AppColors.successBgDark : AppColors.successBg;
          iconColor = AppColors.success;
          icon = Icons.check_circle_rounded;
          title = 'Refund Approved';
          subtitle =
              '${formatInr(refund.amount)} credited to your wallet.';
        } else if (refund.isRejected) {
          bgColor = isDark ? AppColors.dangerBgDark : AppColors.dangerBg;
          iconColor = AppColors.danger;
          icon = Icons.cancel_rounded;
          title = 'Refund Rejected';
          subtitle = refund.adminNotes?.isNotEmpty == true
              ? refund.adminNotes!
              : 'Your refund request was not approved.';
        } else {
          bgColor =
              isDark ? AppColors.warningBgDark : AppColors.warningBg;
          iconColor = AppColors.warning;
          icon = Icons.hourglass_top_rounded;
          title = 'Refund Pending';
          subtitle =
              'Your refund request is being processed (3–5 business days).';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: AppTypography.label
                            .copyWith(color: iconColor)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.caption.copyWith(
                            color: iconColor.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

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
    final valueStyle =
        (bold ? AppTypography.heading3 : AppTypography.label).copyWith(
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
