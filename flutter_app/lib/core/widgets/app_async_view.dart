import 'package:flutter/material.dart';

import 'app_empty_state.dart';
import 'shimmer_loader.dart';

/// Drop-in wrapper that shows a shimmer skeleton while loading,
/// a themed error state on failure, and the real [child] on success.
///
/// The [skeleton] parameter lets callers provide a custom shimmer widget.
/// If omitted, a [SkeletonScreen] with [skeletonItemCount] list tiles is used.
class AppAsyncView extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.child,
    this.onRetry,
    this.skeleton,
    this.skeletonItemCount = 4,
  });

  final bool isLoading;
  final String? error;
  final Widget child;
  final VoidCallback? onRetry;

  /// Custom shimmer widget shown while loading. Defaults to [SkeletonScreen].
  final Widget? skeleton;

  /// Item count for the default [SkeletonScreen] skeleton.
  final int skeletonItemCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return skeleton ?? SkeletonScreen(itemCount: skeletonItemCount);
    }

    if (error != null && error!.trim().isNotEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        subtitle: error,
        actionLabel: onRetry != null ? 'Try Again' : null,
        onAction: onRetry,
        iconColor: Theme.of(context).colorScheme.error,
      );
    }

    return child;
  }
}
