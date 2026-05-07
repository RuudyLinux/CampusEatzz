import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Liquid Glass blob background.
/// Blobs are painted once and isolated — they never repaint on scroll/rebuild.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkBackgroundGradient
            : AppColors.backgroundGradient,
      ),
      child: Stack(
        children: <Widget>[
          // Blobs in a single RepaintBoundary — blur is expensive, isolate it.
          RepaintBoundary(
            child: Stack(
              children: <Widget>[
                _Blob(
                  top: -80, left: -40,
                  size: 300,
                  color: isDark ? AppColors.blobDark1 : AppColors.blobLight1,
                ),
                _Blob(
                  bottom: -100, right: -50,
                  size: 280,
                  color: isDark ? AppColors.blobDark2 : AppColors.blobLight2,
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final double size;
  final Color color;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55, tileMode: TileMode.decal),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}
