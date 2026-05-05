import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_backdrop.dart';
import '../../core/widgets/gradient_header.dart';
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
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().session;

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
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
            const GradientHeader(title: 'Order Successful', subtitle: 'Your order has been placed'),
            Expanded(
              child: FutureBuilder<OrderDetails>(
                future: context.read<OrdersProvider>().loadOrderDetails(
                      identifier: user.identifier,
                      orderRef: widget.orderRef,
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(snapshot.error?.toString() ?? 'Unable to load order details.'),
                      ),
                    );
                  }

                  final order = snapshot.data;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      AnimatedReveal(
                        delayMs: 70,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: <Widget>[
                                const CircleAvatar(
                                  radius: 36,
                                  backgroundColor: AppColors.successBg,
                                  child: Icon(Icons.check, size: 40, color: AppColors.success),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Order Placed Successfully!',
                                  style: AppTypography.heading1,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Thank you for your order, ${user.name}!',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 14),
                                _line('Order Number', order!.orderNumber),
                                _line('Order Date', formatDateTime(order.createdAt)),
                                _line('Order Status', titleCase(order.status)),
                                _line('Payment Status', titleCase(order.paymentStatus)),
                                const Divider(height: 22),
                                _line('Subtotal', formatInr(order.subtotal)),
                                _line('Tax', formatInr(order.tax)),
                                _line('Total', formatInr(order.total), bold: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedReveal(
                        delayMs: 140,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text("What's Next?", style: AppTypography.heading3),
                                const SizedBox(height: 8),
                                const Text('• Your order has been sent to the canteen'),
                                const Text('• You will receive updates on order status'),
                                const Text('• Feedback request will be sent after completion'),
                                const Text('• You can track order from profile/orders page'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedReveal(
                        delayMs: 200,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Order More'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedReveal(
                        delayMs: 240,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.list_alt_outlined),
                          label: const Text('View All Orders'),
                        ),
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
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
