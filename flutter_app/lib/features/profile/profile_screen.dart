import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/wallet_provider.dart';
import '../auth/login_screen.dart';
import '../orders/order_details_screen.dart';
import '../orders/orders_screen.dart';
import '../wallet/wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final session = auth.session;
    if (session == null) return;
    await Future.wait<void>(<Future<void>>[
      auth.refreshProfile(),
      context.read<OrdersProvider>().loadOrders(session.identifier),
      context.read<WalletProvider>().load(session.identifier),
    ]);
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    await authProvider.logout();
    if (!mounted) return;
    await cartProvider.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrdersProvider>();
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.session;

    if (user == null) {
      return Scaffold(
        bottomNavigationBar:
            const CustomerBottomNav(current: CustomerTab.profile),
        body: Column(
          children: <Widget>[
            const GradientHeader(title: 'My Profile'),
            Expanded(
              child: AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Not Signed In',
                subtitle: 'Please login to view your profile.',
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

    final recent = orders.orders.take(3).toList(growable: false);

    return Scaffold(
      bottomNavigationBar:
          const CustomerBottomNav(current: CustomerTab.profile),
      body: Column(
        children: <Widget>[
          const GradientHeader(
            title: 'My Profile',
            subtitle: 'Personal info & recent orders',
            trailing: NotificationBellButton(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  // ── Avatar + name ─────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 60,
                    child: _AvatarCard(user: user, isDark: isDark),
                  ),
                  const SizedBox(height: 12),

                  // ── Wallet quick view ────────────────────────────────
                  AnimatedReveal(
                    delayMs: 120,
                    child: _WalletBanner(
                      balance: wallet.wallet.balance,
                      isDark: isDark,
                      onManage: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const WalletScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Personal info ────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 180,
                    child: _SectionCard(
                      title: 'Personal Information',
                      isDark: isDark,
                      child: Column(
                        children: <Widget>[
                          _Field(
                            label: 'Name',
                            value: user.firstName.isEmpty
                                ? user.name
                                : user.firstName,
                            isDark: isDark,
                          ),
                          _Field(
                              label: 'Last Name',
                              value: user.lastName,
                              isDark: isDark),
                          _Field(
                              label: 'Email',
                              value: user.email,
                              isDark: isDark),
                          _Field(
                              label: 'Enrollment No.',
                              value: user.universityId,
                              isDark: isDark),
                          _Field(
                              label: 'Contact',
                              value: user.contact,
                              isDark: isDark),
                          _Field(
                              label: 'Department',
                              value: user.department,
                              isDark: isDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Recent orders ────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 240,
                    child: _SectionCard(
                      title: 'Recent Orders',
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (recent.isEmpty)
                            Text(
                              'No recent orders yet.',
                              style: AppTypography.body.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              ),
                            )
                          else
                            ...recent.map((order) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.primaryOnDark
                                            : AppColors.primary)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    size: 18,
                                    color: isDark
                                        ? AppColors.primaryOnDark
                                        : AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  'Order #${order.orderNumber}',
                                  style: AppTypography.label.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${order.itemCount} items • ${formatDate(order.createdAt)}',
                                  style: AppTypography.caption.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.textMuted,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                    const SizedBox(height: 4),
                                    AppStatusBadge.fromString(order.status,
                                        small: true),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => OrderDetailsScreen(
                                          orderRef: order.orderNumber),
                                    ),
                                  );
                                },
                              );
                            }),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const OrdersScreen()),
                              );
                            },
                            icon: const Icon(Icons.list_alt_outlined, size: 16),
                            label: const Text('View All Orders'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Logout ───────────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 300,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded,
                            color: AppColors.danger),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.danger, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar Card ───────────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.user, required this.isDark});

  final dynamic user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.name as String);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: (isDark
                      ? AppColors.primaryOnDark
                      : AppColors.primary)
                  .withValues(alpha: 0.15),
              child: Text(
                initials,
                style: AppTypography.heading2.copyWith(
                  color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.name as String,
                    style: AppTypography.heading3.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email as String,
                    style: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Wallet Banner ─────────────────────────────────────────────────────────────

class _WalletBanner extends StatelessWidget {
  const _WalletBanner({
    required this.balance,
    required this.isDark,
    required this.onManage,
  });

  final double balance;
  final bool isDark;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkHeaderGradient : AppColors.walletGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Wallet Balance',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.80)),
                ),
                const SizedBox(height: 4),
                Text(
                  formatInr(balance),
                  style: AppTypography.priceLg.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onManage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

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
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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

// ── Read-only Field ───────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surfaceRaised,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.body.copyWith(
                color: value.isEmpty
                    ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
