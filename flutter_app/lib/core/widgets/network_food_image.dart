import 'package:flutter/material.dart';

class NetworkFoodImage extends StatelessWidget {
  const NetworkFoodImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    this.height = 120,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrl;
  final String fallbackAsset;
  final double height;
  final double width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = imageUrl.trim().isEmpty
        ? Image.asset(
            fallbackAsset,
            fit: fit,
            width: width,
            height: height,
          )
        : Image.network(
            imageUrl,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) {
              return Image.asset(
                fallbackAsset,
                fit: fit,
                width: width,
                height: height,
              );
            },
          );

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }
}
