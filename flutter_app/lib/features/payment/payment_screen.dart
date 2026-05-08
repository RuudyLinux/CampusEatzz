import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/premium_animations.dart';
import '../../data/models/cart_item.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/wallet_provider.dart';
import '../orders/order_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'wallet';
  bool _processing = false;
  final _upiController = TextEditingController();
  bool _agreeWallet = false;
  bool _agreeUpi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<AuthProvider>().session;
      if (session != null) {
        context.read<WalletProvider>().load(session.identifier);
      }
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_processing) return;

    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    final wallet = context.read<WalletProvider>();
    final orders = context.read<OrdersProvider>();
    final session = auth.session;

    if (session == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }
    if (_method == 'wallet') {
      if (!_agreeWallet) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please agree to wallet terms.')));
        return;
      }
      if (wallet.wallet.balance < cart.total) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient wallet balance.')));
        return;
      }
    }
    if (_method == 'upi') {
      if (_upiController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your UPI ID.')));
        return;
      }
      if (!_agreeUpi) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please agree to the terms.')));
        return;
      }
    }

    setState(() => _processing = true);
    try {
      final result = await orders.placeOrder(
        identifier: session.identifier,
        paymentMethod: _method,
        items: cart.items,
        canteenId: cart.activeCanteenId,
        customerName: session.name,
        customerPhone: session.contact,
        orderType: cart.isParcel ? 'parcel' : 'takeaway',
      );

      if (result.walletBalance != null) {
        wallet.applyLocalBalance(result.walletBalance!);
      }
      await cart.clear();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessScreen(orderRef: result.orderNumber),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cart.items.isEmpty) {
      return Scaffold(
        body: Column(
          children: <Widget>[
            const GradientHeader(
                title: 'Checkout', subtitle: 'Complete your order'),
            Expanded(
              child: AppEmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Cart is Empty',
                subtitle: 'Add items to your cart before checking out.',
                actionLabel: 'Go Back',
                onAction: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    // Full-screen processing overlay
    if (_processing) {
      return Scaffold(
        body: Center(
          child: PaymentProcessingWidget(isDark: isDark),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'Checkout',
            subtitle: 'Secure payment',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                // Order Summary
                AnimatedReveal(
                  delayMs: 60,
                  child: _OrderSummaryCard(
                    items: cart.items,
                    subtotal: cart.subtotal,
                    tax: cart.tax,
                    total: cart.total,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 14),

                // Payment method selector
                AnimatedReveal(
                  delayMs: 120,
                  child: _PaymentMethodSelector(
                    selected: _method,
                    isDark: isDark,
                    onChanged: (m) => setState(() => _method = m),
                  ),
                ),
                const SizedBox(height: 14),

                // Method details
                if (_method == 'wallet')
                  AnimatedReveal(
                    delayMs: 180,
                    child: _WalletSection(
                      walletBalance: wallet.wallet.balance,
                      total: cart.total,
                      isDark: isDark,
                      agreed: _agreeWallet,
                      onAgree: (v) => setState(() => _agreeWallet = v),
                    ),
                  ),
                if (_method == 'upi')
                  AnimatedReveal(
                    delayMs: 180,
                    child: _UpiSection(
                      controller: _upiController,
                      total: cart.total,
                      isDark: isDark,
                      agreed: _agreeUpi,
                      onAgree: (v) => setState(() => _agreeUpi = v),
                    ),
                  ),
                if (_method == 'cash')
                  AnimatedReveal(
                    delayMs: 180,
                    child: _CashSection(
                      subtotal: cart.subtotal,
                      tax: cart.tax,
                      total: cart.total,
                      isDark: isDark,
                    ),
                  ),

                const SizedBox(height: 14),

                // Pay button
                AnimatedReveal(
                  delayMs: 240,
                  child: PressScaleButton(
                    onTap: _placeOrder,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.lock_rounded, size: 18),
                        label: Text('Pay ${formatInr(cart.total)}'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Summary ─────────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.isDark,
  });

  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Order Summary',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${item.name} × ${item.quantity}',
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatInr(item.lineTotal),
                      style: AppTypography.label.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            Divider(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              height: 20,
            ),
            _Row(label: 'Subtotal', value: formatInr(subtotal), isDark: isDark),
            const SizedBox(height: 4),
            _Row(label: 'Tax (5%)', value: formatInr(tax), isDark: isDark),
            Divider(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              height: 20,
            ),
            _Row(
                label: 'Total',
                value: formatInr(total),
                isDark: isDark,
                bold: true),
          ],
        ),
      ),
    );
  }
}

// ── Payment Method Selector ───────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _MethodChip(
          methodKey: 'wallet',
          icon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
          selected: selected,
          isDark: isDark,
          onTap: onChanged,
        ),
        const SizedBox(width: 10),
        _MethodChip(
          methodKey: 'upi',
          icon: Icons.phone_android_rounded,
          label: 'UPI',
          selected: selected,
          isDark: isDark,
          onTap: onChanged,
        ),
        const SizedBox(width: 10),
        _MethodChip(
          methodKey: 'cash',
          icon: Icons.money_rounded,
          label: 'Cash',
          selected: selected,
          isDark: isDark,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.methodKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String methodKey;
  final IconData icon;
  final String label;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = selected == methodKey;
    final activeColor = isDark ? AppColors.primaryOnDark : AppColors.primary;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(methodKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: isDark ? 0.18 : 0.10)
                : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.50)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: 1.5,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon,
                  color: isActive
                      ? activeColor
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted)),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isActive
                      ? activeColor
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wallet Section ────────────────────────────────────────────────────────────

class _WalletSection extends StatelessWidget {
  const _WalletSection({
    required this.walletBalance,
    required this.total,
    required this.isDark,
    required this.agreed,
    required this.onAgree,
  });

  final double walletBalance;
  final double total;
  final bool isDark;
  final bool agreed;
  final ValueChanged<bool> onAgree;

  @override
  Widget build(BuildContext context) {
    final remaining = walletBalance - total;
    final sufficient = remaining >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Wallet Payment',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _Row(
                label: 'Wallet Balance',
                value: formatInr(walletBalance),
                isDark: isDark),
            const SizedBox(height: 6),
            _Row(
                label: 'Order Total',
                value: formatInr(total),
                isDark: isDark),
            Divider(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              height: 20,
            ),
            _Row(
              label: 'After Payment',
              value: formatInr(remaining),
              isDark: isDark,
              bold: true,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sufficient
                    ? (isDark
                        ? AppColors.successBgDark
                        : AppColors.successBg)
                    : (isDark ? AppColors.dangerBgDark : AppColors.dangerBg),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    sufficient
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: sufficient ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sufficient
                          ? 'Sufficient balance available.'
                          : 'Insufficient balance. Please recharge your wallet.',
                      style: AppTypography.bodySm.copyWith(
                        color:
                            sufficient ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              value: agreed,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => onAgree(v ?? false),
              title: Text(
                'I agree to wallet payment terms.',
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── UPI Section ───────────────────────────────────────────────────────────────

class _UpiSection extends StatelessWidget {
  const _UpiSection({
    required this.controller,
    required this.total,
    required this.isDark,
    required this.agreed,
    required this.onAgree,
  });

  final TextEditingController controller;
  final double total;
  final bool isDark;
  final bool agreed;
  final ValueChanged<bool> onAgree;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'UPI Payment',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'yourname@upi',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _Row(
                label: 'Payable Amount',
                value: formatInr(total),
                isDark: isDark,
                bold: true),
            CheckboxListTile(
              value: agreed,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => onAgree(v ?? false),
              title: Text(
                'I agree to the terms and conditions.',
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cash Section ──────────────────────────────────────────────────────────────

class _CashSection extends StatelessWidget {
  const _CashSection({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.isDark,
  });

  final double subtotal;
  final double tax;
  final double total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pay at Counter',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _Row(label: 'Subtotal', value: formatInr(subtotal), isDark: isDark),
            const SizedBox(height: 4),
            _Row(label: 'Tax (5%)', value: formatInr(tax), isDark: isDark),
            Divider(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              height: 20,
            ),
            _Row(
                label: 'Total',
                value: formatInr(total),
                isDark: isDark,
                bold: true),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.bgSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please keep the exact amount ready at the counter.',
                      style: AppTypography.bodySm.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
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
}

// ── Row helper ────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.isDark,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final style = bold
        ? AppTypography.heading3.copyWith(color: color)
        : AppTypography.body.copyWith(color: mutedColor);

    return Row(
      children: <Widget>[
        Text(label, style: style),
        const Spacer(),
        Text(value,
            style: style.copyWith(
              color: bold ? color : mutedColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            )),
      ],
    );
  }
}
