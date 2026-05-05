import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../core/widgets/global_actions.dart';
import '../../data/services/customer_service.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/theme_provider.dart';
import '../../state/wallet_provider.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../orders/refund_history_screen.dart';
import '../wallet/wallet_screen.dart';
import 'saved_canteens_screen.dart';

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
    final nav = Navigator.of(context);
    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?', style: AppTypography.heading3),
        content: Text(
          'You\'ll need to sign in again to access your account.',
          style: AppTypography.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await authProvider.logout();
    if (!mounted) return;
    await cartProvider.clear();
    if (!mounted) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrdersProvider>();
    final wallet = context.watch<WalletProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.session;

    if (user == null) {
      return Scaffold(
        bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.profile),
        body: SafeArea(
          child: AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Not Signed In',
            subtitle: 'Please login to view your profile.',
            actionLabel: 'Sign In',
            onAction: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          ),
        ),
      );
    }

    final totalOrders = orders.orders.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.profile),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: <Widget>[
            // ── Minimal top app bar ───────────────────────────────────────
            SliverAppBar(
              backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
              elevation: 0,
              pinned: false,
              expandedHeight: 0,
              toolbarHeight: 0,
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Page title ───────────────────────────────────────
                    AnimatedReveal(
                      delayMs: 0,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Profile',
                              style: AppTypography.display.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          GlobalActions(
                            iconColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Avatar card ───────────────────────────────────────
                    AnimatedReveal(
                      delayMs: 50,
                      child: _AvatarCard(user: user, isDark: isDark),
                    ),
                    const SizedBox(height: 16),

                    // ── Wallet balance card ───────────────────────────────
                    AnimatedReveal(
                      delayMs: 100,
                      child: _WalletCard(
                        balance: wallet.wallet.balance,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const WalletScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Account section ───────────────────────────────────
                    AnimatedReveal(
                      delayMs: 140,
                      child: _SectionLabel(label: 'Account', isDark: isDark),
                    ),
                    const SizedBox(height: 10),
                    AnimatedReveal(
                      delayMs: 160,
                      child: _MenuGroup(
                        isDark: isDark,
                        items: <_MenuItem>[
                          _MenuItem(
                            icon: Icons.receipt_long_rounded,
                            iconColor: AppColors.primary,
                            title: 'My orders',
                            subtitle: '$totalOrders placed',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const OrdersScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.undo_rounded,
                            iconColor: const Color(0xFF2C9E68),
                            title: 'My Refunds',
                            subtitle: 'Track refund requests',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const RefundHistoryScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.storefront_rounded,
                            iconColor: const Color(0xFFE91E63),
                            title: 'Saved canteens',
                            subtitle: 'Your favourite spots',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const SavedCanteensScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.credit_card_rounded,
                            iconColor: const Color(0xFF9C27B0),
                            title: 'Payment methods',
                            subtitle: 'CampusWallet · UPI',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const WalletScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Preferences section ───────────────────────────────
                    AnimatedReveal(
                      delayMs: 200,
                      child: _SectionLabel(label: 'Preferences', isDark: isDark),
                    ),
                    const SizedBox(height: 10),
                    AnimatedReveal(
                      delayMs: 220,
                      child: _MenuGroup(
                        isDark: isDark,
                        items: <_MenuItem>[
                          _MenuItem(
                            icon: Icons.notifications_outlined,
                            iconColor: const Color(0xFFFF9800),
                            title: 'Notifications',
                            subtitle: 'Orders, deals, streak',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const NotificationsScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.tune_rounded,
                            iconColor: AppColors.accent,
                            title: 'Taste profile',
                            subtitle: 'Set your food preferences',
                            onTap: () => _comingSoon('Taste profile'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Dark mode toggle row ───────────────────────────────
                    AnimatedReveal(
                      delayMs: 250,
                      child: _DarkModeRow(
                        isDark: isDark,
                        enabled: themeProvider.isDark,
                        onToggle: () => themeProvider.toggle(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Logout ────────────────────────────────────────────
                    AnimatedReveal(
                      delayMs: 290,
                      child: _LogoutRow(isDark: isDark, onTap: _logout),
                    ),
                    const SizedBox(height: 32),

                    // ── Version ───────────────────────────────────────────
                    AnimatedReveal(
                      delayMs: 320,
                      child: Center(
                        child: Text(
                          'CampusEatzz v1.0.0',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Avatar Card ───────────────────────────────────────────────────────────────

class _AvatarCard extends StatefulWidget {
  const _AvatarCard({required this.user, required this.isDark});

  final dynamic user;
  final bool isDark;

  @override
  State<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<_AvatarCard> {
  bool _uploading = false;

  void _showDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailsSheet(user: widget.user, isDark: widget.isDark),
    );
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final service = context.read<CustomerService>();
    final session = auth.session;
    if (session == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final relUrl = await service.uploadProfileImage(
        identifier: session.identifier,
        fileName: picked.name.isNotEmpty ? picked.name : 'profile.jpg',
        bytes: bytes,
      );

      await auth.updateProfileImage(relUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isDark = widget.isDark;
    final initials = _initials(user.name as String);
    final profileImageUrl = (user.profileImageUrl as String).trim();
    final hasImage = profileImageUrl.isNotEmpty;

    // Build absolute URL if relative
    String? absoluteImageUrl;
    if (hasImage) {
      absoluteImageUrl = profileImageUrl.startsWith('http')
          ? profileImageUrl
          : '${ApiConfig.primaryBaseUrl}$profileImageUrl';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // ── Avatar circle with camera overlay ──────────────────────
          GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Stack(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage && absoluteImageUrl != null
                      ? Image.network(
                          absoluteImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initials,
                              style: AppTypography.heading2.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: AppTypography.heading2.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(3),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
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
                  style: AppTypography.bodySm.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
                if ((user.universityId as String).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    user.universityId as String,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Open details button
          GestureDetector(
            onTap: _showDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                'Open',
                style: AppTypography.labelSm
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── User Details Bottom Sheet ─────────────────────────────────────────────────

class _UserDetailsSheet extends StatelessWidget {
  const _UserDetailsSheet({required this.user, required this.isDark});
  final dynamic user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fields = <_DetailField>[
      _DetailField(label: 'First Name', value: user.firstName as String),
      _DetailField(label: 'Last Name', value: user.lastName as String),
      _DetailField(label: 'Email', value: user.email as String),
      _DetailField(
          label: 'Enrollment No.', value: user.universityId as String),
      _DetailField(label: 'Contact', value: user.contact as String),
      _DetailField(label: 'Department', value: user.department as String),
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'My Details',
            style: AppTypography.heading3.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...fields.map((f) => _DetailRow(field: f, isDark: isDark)),
        ],
      ),
    );
  }
}

class _DetailField {
  const _DetailField({required this.label, required this.value});
  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.field, required this.isDark});
  final _DetailField field;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              field.label,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              field.value.isEmpty ? '—' : field.value,
              style: AppTypography.bodySm.copyWith(
                color: field.value.isEmpty
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

// ── Wallet Card ───────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.balance,
    required this.isDark,
    required this.onTap,
  });

  final double balance;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkHeaderGradient
              : AppColors.walletGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Wallet Balance',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInr(balance),
                    style: AppTypography.priceLg.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                'Manage',
                style: AppTypography.labelSm.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSm.copyWith(
        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        letterSpacing: 1.0,
        fontSize: 11,
      ),
    );
  }
}

// ── Menu Group + Item ─────────────────────────────────────────────────────────

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, required this.isDark});

  final List<_MenuItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List<Widget>.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return _MenuRowTile(
            item: item,
            isDark: isDark,
            showDivider: !isLast,
          );
        }),
      ),
    );
  }
}

class _MenuRowTile extends StatelessWidget {
  const _MenuRowTile({
    required this.item,
    required this.isDark,
    required this.showDivider,
  });

  final _MenuItem item;
  final bool isDark;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 20, color: item.iconColor),
                ),
                const SizedBox(width: 14),
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 0,
            color: isDark
                ? AppColors.darkDivider
                : AppColors.divider.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}

// ── Dark Mode Toggle Row ──────────────────────────────────────────────────────

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({
    required this.isDark,
    required this.enabled,
    required this.onToggle,
  });

  final bool isDark;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dark_mode_outlined,
              size: 20,
              color: Color(0xFF5C6BC0),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dark mode',
                  style: AppTypography.label.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'On' : 'Off — follows system',
                  style: AppTypography.caption.copyWith(
                    color:
                        isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.primary,
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.30);
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }
}

// ── Logout Row ────────────────────────────────────────────────────────────────

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.danger.withValues(alpha: 0.12)
              : AppColors.dangerBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Sign out',
                style: AppTypography.label.copyWith(color: AppColors.danger),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.danger.withValues(alpha: 0.60),
            ),
          ],
        ),
      ),
    );
  }
}
