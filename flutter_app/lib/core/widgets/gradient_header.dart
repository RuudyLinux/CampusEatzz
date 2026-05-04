import 'dart:ui';

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

  /// When true: glass card-style header.
  /// When false: deep-green glass gradient header.
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return minimal
        ? _GlassMinimalHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            showLogo: showLogo,
            padding: padding,
            isDark: isDark,
          )
        : _GlassGradientHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            showLogo: showLogo,
            padding: padding,
            isDark: isDark,
          );
  }
}

// ── Minimal — frosted glass card (home screen) ────────────────────────────────

class _GlassMinimalHeader extends StatelessWidget {
  const _GlassMinimalHeader({
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.glassBevelBottom
                    : AppColors.glassBevelTop,
                width: 1,
              ),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 40,
                spreadRadius: 0,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (showLogo) ...<Widget>[
                    // Glass logo badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.mintGlowGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
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
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
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
                            ? AppColors.primaryOnDark
                            : AppColors.primary,
                      ),
                      child: trailing!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient — deep green glass (detail/admin screens) ────────────────────────

class _GlassGradientHeader extends StatelessWidget {
  const _GlassGradientHeader({
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.darkHeaderGradient
                : AppColors.headerGradient,
            border: const Border(
              bottom: BorderSide(color: AppColors.glassBevelTop, width: 1),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 40,
                spreadRadius: 0,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Decorative glass orbs
              Positioned(
                top: -48,
                right: -22,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
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
                    color: Colors.white.withValues(alpha: 0.06),
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
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border.fromBorderSide(
                              BorderSide(
                                  color: AppColors.glassBevelTop, width: 1),
                            ),
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
                                  color: Colors.white.withValues(alpha: 0.82),
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
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border.fromBorderSide(
                              BorderSide(
                                  color: AppColors.glassBevelTop, width: 1),
                            ),
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
      ),
    );
  }
}
