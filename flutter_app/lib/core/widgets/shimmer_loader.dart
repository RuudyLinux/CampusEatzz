import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Animated shimmer wrapper. Wraps child in a sweeping gradient mask.
class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDark
                    ? <Color>[
                        AppColors.darkCard,
                        AppColors.darkBorder,
                        AppColors.darkCardRaised,
                        AppColors.darkBorder,
                        AppColors.darkCard,
                      ]
                    : <Color>[
                        AppColors.surfaceHighest,
                        AppColors.surfaceHigh,
                        Colors.white.withValues(alpha: 0.85),
                        AppColors.surfaceHigh,
                        AppColors.surfaceHighest,
                      ],
                stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                transform: _SlidingGradientTransform(slidePercent: _animation.value),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
}

// ── Shimmer Box ──────────────────────────────────────────────────────────────

/// Single placeholder rectangle. Pass [isDark] from parent to avoid extra Theme lookups.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
    this.isDark,
  });

  final double width;
  final double height;
  final double radius;

  /// Optional — if null, resolved from Theme. Pass from parent for efficiency.
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Pre-built Skeleton Layouts ────────────────────────────────────────────────

class SkeletonCanteenCard extends StatelessWidget {
  const SkeletonCanteenCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBox(width: double.infinity, height: 180, radius: 16, isDark: isDark),
          const SizedBox(height: 10),
          ShimmerBox(width: 160, height: 16, radius: 8, isDark: isDark),
          const SizedBox(height: 6),
          ShimmerBox(width: 220, height: 12, radius: 6, isDark: isDark),
        ],
      ),
    );
  }
}

class SkeletonMenuCard extends StatelessWidget {
  const SkeletonMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBox(width: double.infinity, height: 160, radius: 14, isDark: isDark),
          const SizedBox(height: 10),
          ShimmerBox(width: 180, height: 16, radius: 8, isDark: isDark),
          const SizedBox(height: 6),
          ShimmerBox(width: double.infinity, height: 12, radius: 6, isDark: isDark),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ShimmerBox(width: 70, height: 20, radius: 8, isDark: isDark),
              ShimmerBox(width: 80, height: 36, radius: 12, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoader(
      child: Row(
        children: <Widget>[
          ShimmerBox(width: 44, height: 44, radius: 22, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShimmerBox(width: double.infinity, height: 14, radius: 7, isDark: isDark),
                const SizedBox(height: 6),
                ShimmerBox(width: 140, height: 11, radius: 5, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShimmerBox(width: 60, height: 14, radius: 7, isDark: isDark),
        ],
      ),
    );
  }
}

class SkeletonScreen extends StatelessWidget {
  const SkeletonScreen({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const SkeletonListTile(),
    );
  }
}
