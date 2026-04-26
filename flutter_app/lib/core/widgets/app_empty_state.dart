import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// A reusable empty-state widget: icon + title + optional subtitle + optional CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional override for the icon color; defaults to primary.
  final Color? iconColor;

  /// When [compact] is true the widget uses less vertical padding —
  /// useful inside cards or bottom sheets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? (isDark ? AppColors.primaryOnDark : AppColors.primary);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Icon bubble ──────────────────────────────────────────────────
            Container(
              width: compact ? 72 : 88,
              height: compact ? 72 : 88,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 34 : 42,
                color: effectiveIconColor,
              ),
            ),

            SizedBox(height: compact ? 16 : 20),

            // ── Title ────────────────────────────────────────────────────────
            Text(
              title,
              style: (compact ? AppTypography.heading3 : AppTypography.heading2).copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            // ── Subtitle ─────────────────────────────────────────────────────
            if (subtitle != null) ...<Widget>[
              SizedBox(height: compact ? 6 : 8),
              Text(
                subtitle!,
                style: AppTypography.body.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Action button ─────────────────────────────────────────────────
            if (actionLabel != null && onAction != null) ...<Widget>[
              SizedBox(height: compact ? 20 : 28),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
