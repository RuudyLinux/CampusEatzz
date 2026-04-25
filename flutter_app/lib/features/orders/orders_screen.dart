import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../auth/login_screen.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().session;
      if (user != null) {
        context.read<OrdersProvider>().loadOrders(user.identifier);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final state = context.watch<OrdersProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.session;

    if (user == null) {
      return Scaffold(
        body: Column(
          children: <Widget>[
            const GradientHeader(title: 'My Orders', showLogo: false),
            Expanded(
              child: AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Login Required',
                subtitle: 'Please sign in to view your order history.',
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
            title: 'My Orders',
            subtitle: 'Track your order history',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const SkeletonScreen(itemCount: 5)
                : state.orders.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Orders Yet',
                        subtitle:
                            'Your order history will appear here once you place your first order.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: state.orders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final order = state.orders[index];
                          return AnimatedReveal(
                            delayMs: 60 + (index * 40),
                            child: _OrderTile(
                              order: order,
                              isDark: isDark,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OrderDetailsScreen(
                                        orderRef: order.orderNumber),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Order Tile ────────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.isDark,
    required this.onTap,
  });

  final dynamic order;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primaryOnDark : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Order #${order.orderNumber}',
                      style: AppTypography.label.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} • ${formatDate(order.createdAt)}',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatInr(order.total),
                    style: AppTypography.priceSm.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AppStatusBadge.fromString(order.status, small: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
