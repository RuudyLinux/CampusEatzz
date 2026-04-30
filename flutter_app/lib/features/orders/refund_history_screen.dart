import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/refund_models.dart';
import '../../state/auth_provider.dart';
import '../../state/refund_provider.dart';

class RefundHistoryScreen extends StatefulWidget {
  const RefundHistoryScreen({super.key});

  @override
  State<RefundHistoryScreen> createState() => _RefundHistoryScreenState();
}

class _RefundHistoryScreenState extends State<RefundHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().session;
      if (user != null) {
        context.read<RefundProvider>().loadRefunds(user.identifier);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final refunds = context.watch<RefundProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'My Refunds',
            subtitle: 'Track your refund requests',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: refunds.isLoadingList
                ? const SkeletonScreen(itemCount: 4)
                : refunds.refunds.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.undo_rounded,
                        title: 'No Refunds Yet',
                        subtitle:
                            'Your refund requests will appear here once submitted.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final user = context.read<AuthProvider>().session;
                          if (user != null) {
                            await context
                                .read<RefundProvider>()
                                .loadRefunds(user.identifier);
                          }
                        },
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: refunds.refunds.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => AnimatedReveal(
                            delayMs: 60 + (i * 40),
                            child: _RefundCard(
                              refund: refunds.refunds[i],
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  const _RefundCard({required this.refund, required this.isDark});

  final RefundInfo refund;
  final bool isDark;

  _StatusStyle get _style {
    if (refund.isApproved) {
      return _StatusStyle(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        bg: isDark ? AppColors.successBgDark : AppColors.successBg,
        label: 'Approved',
      );
    }
    if (refund.isRejected) {
      return _StatusStyle(
        icon: Icons.cancel_rounded,
        color: AppColors.danger,
        bg: isDark ? AppColors.dangerBgDark : AppColors.dangerBg,
        label: 'Rejected',
      );
    }
    return _StatusStyle(
      icon: Icons.hourglass_top_rounded,
      color: AppColors.warning,
      bg: isDark ? AppColors.warningBgDark : AppColors.warningBg,
      label: 'Pending',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Header strip
          DecoratedBox(
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(s.icon, size: 16, color: s.color),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: AppTypography.labelSm.copyWith(color: s.color),
                  ),
                  const Spacer(),
                  Text(
                    formatDate(refund.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: s.color.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            refund.orderNumber.isNotEmpty
                                ? 'Order #${refund.orderNumber}'
                                : 'Order #${refund.orderId}',
                            style: AppTypography.label.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            refund.reason,
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
                      formatInr(refund.amount),
                      style: AppTypography.priceSm.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (refund.adminNotes != null &&
                    refund.adminNotes!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            refund.adminNotes!,
                            style: AppTypography.caption.copyWith(
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
                if (refund.isApproved && refund.processedAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Credited on ${formatDate(refund.processedAt)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
}
