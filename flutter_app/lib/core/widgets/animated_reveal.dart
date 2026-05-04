import 'dart:ui';

import 'package:flutter/material.dart';

/// Crystallize entry: fade-in + scale (90%→100%) + backdrop-blur (0→12px).
/// Spec: 400ms, cubic-bezier(0.34, 1.56, 0.64, 1) for spring feel.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 400,
    this.beginOffset = const Offset(0, 0.06),
    this.enableGlassEffect = true,
  });

  final Widget child;
  final int delayMs;
  final int durationMs;
  final Offset beginOffset;

  /// When true: add backdrop-blur crystallize effect (glass spec).
  /// When false: original slide + fade only.
  final bool enableGlassEffect;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeOpacity;
  late Animation<double> _scale;
  late Animation<double> _blurSigma;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMs),
      vsync: this,
    );

    // Cubic-bezier(0.34, 1.56, 0.64, 1) — spring overshoot
    final curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
    );

    _fadeOpacity = Tween<double>(begin: 0, end: 1).animate(curveAnimation);
    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(curveAnimation);
    _blurSigma = widget.enableGlassEffect
        ? Tween<double>(begin: 0, end: 12).animate(curveAnimation)
        : const AlwaysStoppedAnimation(0);
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(curveAnimation);

    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableGlassEffect) {
      return AnimatedSlide(
        duration: Duration(milliseconds: widget.durationMs),
        curve: Curves.easeOutCubic,
        offset: _controller.isCompleted ? Offset.zero : widget.beginOffset,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: widget.durationMs),
          curve: Curves.easeOut,
          opacity: _controller.isCompleted ? 1 : 0,
          child: widget.child,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _fadeOpacity.value.clamp(0.0, 1.0);
        final blurValue = _blurSigma.value.clamp(0.0, 12.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
            child: Transform.translate(
              offset: Offset(
                _slide.value.dx * 50,
                _slide.value.dy * 50,
              ),
              child: Transform.scale(
                scale: _scale.value.clamp(0.90, 1.0),
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
