import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import 'app_logo.dart';

class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showLogo = true,
    this.padding,
    this.minimal = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showLogo;
  final EdgeInsetsGeometry? padding;

  /// When true: white card-style header (screenshot style).
  /// When false: original rose gradient header.
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return minimal
        ? _MinimalHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            showLogo: showLogo,
            padding: padding,
            isDark: isDark,
          )
        : _GradientHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            showLogo: showLogo,
            padding: padding,
            isDark: isDark,
          );
  }
}

// ── Minimal (screenshot style) ────────────────────────────────────────────────

class _MinimalHeader extends StatelessWidget {
  const _MinimalHeader({
    required this.title,
    required this.isDark,
    this.subtitle,
    this.trailing,
    this.showLogo = true,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showLogo;
  final EdgeInsetsGeometry? padding;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkBg : AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (showLogo) ...<Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.shadowPink,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTypography.heading2.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySm.copyWith(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                IconTheme(
                  data: IconThemeData(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient (original, used for admin / detail screens) ──────────────────────

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.title,
    required this.isDark,
    this.subtitle,
    this.trailing,
    this.showLogo = true,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showLogo;
  final EdgeInsetsGeometry? padding;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient:
              isDark ? AppColors.darkHeaderGradient : AppColors.headerGradient,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark
                  ? AppColors.darkBg.withValues(alpha: 0.50)
                  : AppColors.shadowPinkMd,
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -48,
              right: -22,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: isDark ? 0.06 : 0.11),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -28,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: isDark ? 0.05 : 0.09),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (showLogo) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const AppLogo(size: 32),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            style: AppTypography.heading2.copyWith(
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (subtitle != null &&
                              subtitle!.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: AppTypography.bodySm.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: trailing!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
