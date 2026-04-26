import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/network_food_image.dart';
import '../../state/cart_provider.dart';
import '../home/home_screen.dart';
import '../payment/payment_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: <Widget>[
          const GradientHeader(
            title: 'Your Cart',
            subtitle: 'Review items before checkout',
          ),
          Expanded(
            child: cart.items.isEmpty
                ? AnimatedReveal(
                    delayMs: 80,
                    child: AppEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Cart is Empty',
                      subtitle:
                          'Browse canteens and add items to get started.',
                      actionLabel: 'Browse Menu',
                      onAction: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: <Widget>[
                      // ── Items ───────────────────────────────────────────
                      ...cart.items.asMap().entries.map((entry) {
                        final item = entry.value;
                        return AnimatedReveal(
                          delayMs: 60 + (entry.key * 40),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CartItemCard(
                                item: item, isDark: isDark),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // ── Summary + checkout ──────────────────────────────
                      AnimatedReveal(
                        delayMs: 140,
                        child: _OrderSummaryCard(cart: cart, isDark: isDark),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Cart Item Card ────────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item, required this.isDark});

  final dynamic item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkFoodImage(
                imageUrl: item.imageUrl,
                fallbackAsset: 'assets/images/Restaurants.jpg',
                foodName: item.name,
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatInr(item.price),
                    style: AppTypography.label.copyWith(
                      color:
                          isDark ? AppColors.primaryOnDark : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Qty stepper
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _StepperButton(
                          icon: Icons.remove_rounded,
                          onTap: () => context
                              .read<CartProvider>()
                              .decrease(item.menuItemId),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${item.quantity}',
                            style: AppTypography.label.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.add_rounded,
                          onTap: () => context
                              .read<CartProvider>()
                              .increase(item.menuItemId),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatInr(item.lineTotal),
                  style: AppTypography.priceSm.copyWith(
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () =>
                      context.read<CartProvider>().remove(item.menuItemId),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.danger,
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.dangerBg,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

// ── Order Summary Card ────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.cart, required this.isDark});

  final CartProvider cart;
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
            _SummaryRow(
                label: 'Subtotal',
                value: formatInr(cart.subtotal),
                isDark: isDark),
            const SizedBox(height: 6),
            _SummaryRow(
                label: 'Tax (5%)',
                value: formatInr(cart.tax),
                isDark: isDark),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
            ),
            _SummaryRow(
              label: 'Total',
              value: formatInr(cart.total),
              isDark: isDark,
              bold: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PaymentScreen()),
                  );
                },
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Proceed to Checkout'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.read<CartProvider>().clear(),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Clear Cart'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    final color = bold
        ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
        : (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final style = bold
        ? AppTypography.heading3.copyWith(color: color)
        : AppTypography.body.copyWith(color: color);

    return Row(
      children: <Widget>[
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
