import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_backdrop.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/premium_animations.dart';
import '../../data/models/order_models.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import 'orders_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderRef,
  });

  final String orderRef;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _checkDone = false;
  Future<OrderDetails>? _orderFuture;
  bool _futureInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize once — never recreate. Recreating on each build restarts
    // FutureBuilder → new AnimatedSuccessCheck → animation loops infinitely.
    if (!_futureInitialized) {
      final user = context.read<AuthProvider>().session;
      if (user != null) {
        _orderFuture = context.read<OrdersProvider>().loadOrderDetails(
              identifier: user.identifier,
              orderRef: widget.orderRef,
            );
        _futureInitialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().session;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        body: AppBackdrop(
          child: Center(
            child: AnimatedReveal(
              delayMs: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Session expired. Please login again.'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Go to Customer Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppBackdrop(
        child: Column(
          children: <Widget>[
            const GradientHeader(
                title: 'Order Successful',
                subtitle: 'Your order has been placed'),
            Expanded(
              child: FutureBuilder<OrderDetails>(
                future: _orderFuture ?? Future.error('Session expired'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulseLoader(
                            color: isDark
                                ? AppColors.primaryOnDark
                                : AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your order…',
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(snapshot.error?.toString() ??
                            'Unable to load order details.'),
                      ),
                    );
                  }

                  final order = snapshot.data!;

                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          // ── Animated success card ───────────────────────
                          AnimatedReveal(
                            delayMs: 50,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: <Widget>[
                                    AnimatedSuccessCheck(
                                      size: 80,
                                      delayMs: 200,
                                      onComplete: () {
                                        if (mounted) {
                                          setState(() => _checkDone = true);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    if (_checkDone) ...[
                                      Text(
                                        'Order Placed Successfully!',
                                        style: AppTypography.heading1,
                                        textAlign: TextAlign.center,
                                      )
                                          .animate()
                                          .fadeIn(duration: 400.ms)
                                          .slideY(
                                              begin: 0.3,
                                              end: 0,
                                              duration: 400.ms,
                                              curve: Curves.easeOut),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Thank you for your order, ${user.name}!',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.body.copyWith(
                                            color: AppColors.textMuted),
                                      )
                                          .animate()
                                          .fadeIn(
                                              delay: 120.ms, duration: 400.ms),
                                    ] else ...[
                                      // Placeholder height while animating
                                      const SizedBox(height: 52),
                                    ],
                                    const SizedBox(height: 14),
                                    _line('Order Number', order.orderNumber),
                                    _line('Order Date',
                                        formatDateTime(order.createdAt)),
                                    _line('Order Status',
                                        titleCase(order.status)),
                                    _line('Payment Status',
                                        titleCase(order.paymentStatus)),
                                    const Divider(height: 22),
                                    _line('Subtotal', formatInr(order.subtotal)),
                                    _line('Tax', formatInr(order.tax)),
                                    _line('Total', formatInr(order.total),
                                        bold: true),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── What's next card ────────────────────────────
                          AnimatedReveal(
                            delayMs: 180,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            size: 16,
                                            color: isDark
                                                ? AppColors.primaryOnDark
                                                : AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text("What's Next?",
                                            style: AppTypography.heading3),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _NextStep(
                                        text:
                                            'Your order has been sent to the canteen',
                                        delay: 280,
                                        isDark: isDark),
                                    _NextStep(
                                        text:
                                            'You will receive updates on order status',
                                        delay: 360,
                                        isDark: isDark),
                                    _NextStep(
                                        text:
                                            'Feedback request after completion',
                                        delay: 440,
                                        isDark: isDark),
                                    _NextStep(
                                        text:
                                            'Track order from Profile > Orders',
                                        delay: 520,
                                        isDark: isDark),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Action buttons ──────────────────────────────
                          AnimatedReveal(
                            delayMs: 260,
                            child: PressScaleButton(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  SlideFadeRoute(page: const HomeScreen()),
                                  (route) => false,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.home_rounded),
                                  label: const Text('Go to Home'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedReveal(
                            delayMs: 300,
                            child: PressScaleButton(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  SlideFadeRoute(page: const HomeScreen()),
                                  (route) => false,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(
                                      Icons.restaurant_menu_rounded),
                                  label: const Text('Order More'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedReveal(
                            delayMs: 340,
                            child: PressScaleButton(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  SlideFadeRoute(page: const OrdersScreen()),
                                  (route) => false,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: null,
                                  icon:
                                      const Icon(Icons.list_alt_outlined),
                                  label: const Text('View All Orders'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = bold
        ? AppTypography.heading3.copyWith(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          )
        : AppTypography.body.copyWith(
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.text,
    required this.delay,
    required this.isDark,
  });

  final String text;
  final int delay;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryOnDark : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color:
                    isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(delay: delay.ms, duration: 350.ms)
          .slideX(begin: -0.1, end: 0, duration: 350.ms),
    );
  }
}
