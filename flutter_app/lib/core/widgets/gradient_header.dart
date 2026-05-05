import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'app_logo.dart';

/// Liquid Glass header — iOS 26 aesthetic.
/// minimal=true  → frosted glass card (home screen, profile)
/// minimal=false → deep frosted panel (detail screens)
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
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _LiquidGlassHeader(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      showLogo: showLogo,
      padding: padding,
      isDark: isDark,
      minimal: minimal,
    );
  }
}

class _LiquidGlassHeader extends StatelessWidget {
  const _LiquidGlassHeader({
    required this.title,
    required this.isDark,
    required this.minimal,
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
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    // Background color for the glass
    final bgColor = isDark ? AppColors.headerBgDark : AppColors.headerBgLight;
    final borderColor = isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop;
    final topEdge = isDark ? AppColors.darkGlassBevelTop : AppColors.glassBevelTop;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
              top: BorderSide(color: topEdge.withValues(alpha: isDark ? 0.20 : 0.95), width: 1),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (showLogo) ...<Widget>[
                    _GlassLogoBox(isDark: isDark),
                    const SizedBox(width: 12),
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
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
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
                    _GlassIconBox(isDark: isDark, child: trailing!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassLogoBox extends StatelessWidget {
  const _GlassLogoBox({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.08),
                ]
              : <Color>[
                  Colors.white.withValues(alpha: 0.80),
                  Colors.white.withValues(alpha: 0.50),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.30 : 0.90),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const AppLogo(size: 22),
    );
  }
}

class _GlassIconBox extends StatelessWidget {
  const _GlassIconBox({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.80),
        ),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          size: 22,
        ),
        child: child,
      ),
    );
  }
}
