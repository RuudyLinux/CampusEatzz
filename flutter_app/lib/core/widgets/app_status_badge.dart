import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Order / item status values used across the app.
enum AppStatus {
  pending,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled,
  paid,
  unpaid,
  refunded,
  active,
  inactive,
}

extension _AppStatusProps on AppStatus {
  String get label {
    switch (this) {
      case AppStatus.pending:
        return 'Pending';
      case AppStatus.confirmed:
        return 'Confirmed';
      case AppStatus.preparing:
        return 'Preparing';
      case AppStatus.ready:
        return 'Ready';
      case AppStatus.completed:
        return 'Completed';
      case AppStatus.cancelled:
        return 'Cancelled';
      case AppStatus.refunded:
        return 'Refunded';
      case AppStatus.paid:
        return 'Paid';
      case AppStatus.unpaid:
        return 'Unpaid';
      case AppStatus.active:
        return 'Active';
      case AppStatus.inactive:
        return 'Inactive';
    }
  }

  Color foreground(bool isDark) {
    switch (this) {
      case AppStatus.pending:
        return AppColors.warning;
      case AppStatus.confirmed:
        return AppColors.info;
      case AppStatus.preparing:
        return isDark ? AppColors.primaryOnDark : AppColors.primary;
      case AppStatus.ready:
        return AppColors.accent;
      case AppStatus.completed:
      case AppStatus.paid:
      case AppStatus.active:
        return AppColors.success;
      case AppStatus.cancelled:
      case AppStatus.unpaid:
      case AppStatus.inactive:
        return AppColors.danger;
      case AppStatus.refunded:
        return AppColors.info;
    }
  }

  Color background(bool isDark) {
    switch (this) {
      case AppStatus.pending:
        return isDark ? AppColors.warningBgDark : AppColors.warningBg;
      case AppStatus.confirmed:
        return AppColors.info.withValues(alpha: isDark ? 0.18 : 0.12);
      case AppStatus.preparing:
        return (isDark ? AppColors.primaryOnDark : AppColors.primary)
            .withValues(alpha: isDark ? 0.15 : 0.10);
      case AppStatus.ready:
        return AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.12);
      case AppStatus.completed:
      case AppStatus.paid:
      case AppStatus.active:
        return isDark ? AppColors.successBgDark : AppColors.successBg;
      case AppStatus.cancelled:
      case AppStatus.unpaid:
      case AppStatus.inactive:
        return isDark ? AppColors.dangerBgDark : AppColors.dangerBg;
      case AppStatus.refunded:
        return AppColors.infoBg;
    }
  }
}

/// A pill-shaped status badge.
///
/// Use [AppStatusBadge.fromString] when the status comes from the API as a string.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge(this.status, {super.key, this.small = false});

  /// Construct from a raw API status string (case-insensitive).
  factory AppStatusBadge.fromString(String raw, {bool small = false}) {
    final mapped = _fromString(raw);
    return AppStatusBadge(mapped, small: small);
  }

  final AppStatus status;

  /// When true, renders a smaller badge (font 10, padding 4×8).
  final bool small;

  static AppStatus _fromString(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'pending':
        return AppStatus.pending;
      case 'confirmed':
        return AppStatus.confirmed;
      case 'preparing':
        return AppStatus.preparing;
      case 'ready':
        return AppStatus.ready;
      case 'completed':
        return AppStatus.completed;
      case 'cancelled':
      case 'canceled':
        return AppStatus.cancelled;
      case 'paid':
        return AppStatus.paid;
      case 'refunded':
        return AppStatus.refunded;
      case 'unpaid':
        return AppStatus.unpaid;
      case 'active':
      case 'open':
        return AppStatus.active;
      case 'inactive':
      case 'closed':
        return AppStatus.inactive;
      default:
        return AppStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = status.foreground(isDark);
    final bg = status.background(isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        // Glass chip: semi-transparent fill, thin border
        color: bg.withValues(alpha: isDark ? 0.55 : 0.45),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: fg.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: (small ? AppTypography.labelSm : AppTypography.label)
            .copyWith(color: fg),
      ),
    );
  }
}
