import 'package:flutter/material.dart';

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
    final resolvedUrl = FoodImageResolver.normalizeImageUrl(imageUrl);
    final resolvedFallbackAsset = FoodImageResolver.assetForFoodName(foodName ?? '') ?? fallbackAsset;
    final preferredMenuUploadUrl = FoodImageResolver.uploadUrlForFoodName(foodName ?? '');

    Widget buildAssetFallback() {
      return Image.asset(
        resolvedFallbackAsset,
        fit: fit,
        width: width,
        height: height,
      );
    }

    Widget buildNetworkImage(String url, Widget fallback) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final secondaryFallback = preferredMenuUploadUrl != null && preferredMenuUploadUrl != resolvedUrl
        ? buildNetworkImage(preferredMenuUploadUrl, buildAssetFallback())
        : buildAssetFallback();

    final primaryUrl = resolvedUrl.isNotEmpty ? resolvedUrl : preferredMenuUploadUrl ?? '';

    final child = primaryUrl.isEmpty
        ? buildAssetFallback()
        : buildNetworkImage(primaryUrl, secondaryFallback);

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }
}
