import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/food_image_resolver.dart';

class NetworkFoodImage extends StatelessWidget {
  const NetworkFoodImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    this.foodName,
    this.height = 120,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrl;
  final String fallbackAsset;
  final String? foodName;
  final double height;
  final double width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedUrl = FoodImageResolver.normalizeImageUrl(imageUrl);
    final resolvedFallbackAsset =
        FoodImageResolver.assetForFoodName(foodName ?? '') ?? fallbackAsset;
    final preferredMenuUploadUrl =
        FoodImageResolver.uploadUrlForFoodName(foodName ?? '');

    Widget buildAssetFallback() => Image.asset(
          resolvedFallbackAsset,
          fit: fit,
          width: width,
          height: height,
        );

    Widget buildShimmerPlaceholder() => _ShimmerPlaceholder(
          width: width,
          height: height,
          isDark: isDark,
        );

    Widget buildCachedImage(String url, Widget fallback) => CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: width,
          height: height,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
          placeholder: (_, __) => buildShimmerPlaceholder(),
          errorWidget: (_, __, ___) => fallback,
        );

    final secondaryFallback =
        preferredMenuUploadUrl != null && preferredMenuUploadUrl != resolvedUrl
            ? buildCachedImage(preferredMenuUploadUrl, buildAssetFallback())
            : buildAssetFallback();

    final primaryUrl =
        resolvedUrl.isNotEmpty ? resolvedUrl : preferredMenuUploadUrl ?? '';

    final child = primaryUrl.isEmpty
        ? buildAssetFallback()
        : buildCachedImage(primaryUrl, secondaryFallback);

    if (borderRadius == null) return child;

    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

/// Shimmer placeholder sized to match the image slot.
class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder({
    required this.width,
    required this.height,
    required this.isDark,
  });

  final double width;
  final double height;
  final bool isDark;

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? AppColors.darkCard : AppColors.surfaceHighest;
    final shine = widget.isDark ? AppColors.darkBorder : AppColors.surfaceHigh;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[base, shine, base],
            stops: const <double>[0.0, 0.5, 1.0],
            transform: _SlideTransform(_anim.value),
          ).createShader(bounds),
          child: Container(
            width: widget.width,
            height: widget.height,
            color: base,
          ),
        ),
      ),
    );
  }
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.slide);
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}
