import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/gradient_header.dart';
import '../../data/models/order_models.dart';
import '../../state/auth_provider.dart';
import '../../state/refund_provider.dart';
import '../../state/wallet_provider.dart';

class RefundRequestScreen extends StatefulWidget {
  const RefundRequestScreen({super.key, required this.order});

  final OrderDetails order;

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  static const _reasons = [
    'Order cancelled by canteen',
    'Wrong items received',
    'Food quality issue',
    'Order not received',
    'Waited too long',
    'Other',
  ];

  String? _selectedReason;
  bool _submitting = false;

  bool get _isWallet =>
      widget.order.paymentMethod.toLowerCase() == 'online' ||
      widget.order.paymentMethod.toLowerCase() == 'wallet';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'Request Refund',
            subtitle: 'Order #${widget.order.orderNumber}',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: <Widget>[
                _RefundAmountCard(
                  total: widget.order.total,
                  isWallet: _isWallet,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Reason',
                  style: AppTypography.heading3.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._reasons.map((reason) => _ReasonTile(
                      reason: reason,
                      selected: _selectedReason == reason,
                      isDark: isDark,
                      onTap: () =>
                          setState(() => _selectedReason = reason),
                    )),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _selectedReason == null || _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.primaryOnDark : AppColors.primary,
                      disabledBackgroundColor:
                          isDark ? AppColors.darkBorder : AppColors.divider,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit Refund Request',
                            style:
                                AppTypography.label.copyWith(color: Colors.white),
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

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final refund = context.read<RefundProvider>();
    final wallet = context.read<WalletProvider>();

    try {
      final result = await refund.requestRefund(
        identifier: auth.session!.identifier,
        orderRef: widget.order.orderNumber,
        reason: _selectedReason!,
      );

      if (result.walletBalance != null) {
        wallet.applyLocalBalance(result.walletBalance!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status == 'approved'
                ? 'Refund of ${formatInr(result.amount)} credited to wallet!'
                : 'Refund request submitted. Processing in 3-5 days.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _submitting = false);
    }
  }
}

class _RefundAmountCard extends StatelessWidget {
  const _RefundAmountCard({
    required this.total,
    required this.isWallet,
    required this.isDark,
  });

  final double total;
  final bool isWallet;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Refund Amount',
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatInr(total),
              style: AppTypography.heading2.copyWith(
                color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isWallet
                    ? (isDark
                        ? AppColors.successBgDark
                        : AppColors.successBg)
                    : (isDark
                        ? AppColors.warningBgDark
                        : AppColors.warningBg),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isWallet
                        ? Icons.account_balance_wallet_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: isWallet ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isWallet
                        ? 'Instant wallet credit'
                        : 'Manual processing (3–5 business days)',
                    style: AppTypography.caption.copyWith(
                      color: isWallet ? AppColors.success : AppColors.warning,
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

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? AppColors.primaryOnDark.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.07))
              : (isDark ? AppColors.darkSurface : Colors.white),
          border: Border.all(
            color: selected
                ? (isDark
                    ? AppColors.primaryOnDark
                    : AppColors.primary)
                : (isDark ? AppColors.darkBorder : AppColors.divider),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected
                  ? (isDark
                      ? AppColors.primaryOnDark
                      : AppColors.primary)
                  : (isDark
                      ? AppColors.darkTextMuted
                      : AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            Text(
              reason,
              style: AppTypography.body.copyWith(
                color: selected
                    ? (isDark
                        ? AppColors.primaryOnDark
                        : AppColors.primary)
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
