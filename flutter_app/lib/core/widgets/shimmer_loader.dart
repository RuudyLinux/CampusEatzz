import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Animated shimmer effect for loading skeletons.
/// Uses a TweenAnimationBuilder so no external packages are needed.
class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
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
                      AppColors.border.withValues(alpha: 0.6),
                      AppColors.bgSoft,
                      Colors.white,
                      AppColors.bgSoft,
                      AppColors.border.withValues(alpha: 0.6),
                    ],
              stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

// ── Shimmer Box ──────────────────────────────────────────────────────────────

/// A single placeholder rectangle for use in skeleton layouts.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.bgSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Pre-built Skeleton Layouts ────────────────────────────────────────────────

/// Skeleton for a home-screen canteen card (image + 2 text lines).
class SkeletonCanteenCard extends StatelessWidget {
  const SkeletonCanteenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBox(width: double.infinity, height: 180, radius: 16),
          const SizedBox(height: 10),
          ShimmerBox(width: 160, height: 16, radius: 8),
          const SizedBox(height: 6),
          ShimmerBox(width: 220, height: 12, radius: 6),
        ],
      ),
    );
  }
}

/// Skeleton for a menu item card (image + name + price row).
class SkeletonMenuCard extends StatelessWidget {
  const SkeletonMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBox(width: double.infinity, height: 160, radius: 14),
          const SizedBox(height: 10),
          ShimmerBox(width: 180, height: 16, radius: 8),
          const SizedBox(height: 6),
          ShimmerBox(width: double.infinity, height: 12, radius: 6),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ShimmerBox(width: 70, height: 20, radius: 8),
              ShimmerBox(width: 80, height: 36, radius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a transaction / order list item.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Row(
        children: <Widget>[
          const ShimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ShimmerBox(width: double.infinity, height: 14, radius: 7),
                const SizedBox(height: 6),
                ShimmerBox(width: 140, height: 11, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 60, height: 14, radius: 7),
        ],
      ),
    );
  }
}

/// A full-screen shimmer skeleton for content that needs multiple items.
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
