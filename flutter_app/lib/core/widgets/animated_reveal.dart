import 'package:flutter/material.dart';

/// Crystallize entry: fade-in + slide (offset→zero) + scale (96%→100%).
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 280,
    this.beginOffset = const Offset(0, 0.04),
    this.enableGlassEffect = false,
  });

  final Widget child;
  final int delayMs;
  final int durationMs;
  final Offset beginOffset;

  // Kept for API compatibility — unused (BackdropFilter per-widget too expensive).
  final bool enableGlassEffect;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMs),
      vsync: this,
    );

    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _fade  = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(curve);
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(curve);

    if (widget.delayMs == 0) {
      _controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition cheaper than Opacity — skips layout pass on opacity change.
    // ScaleTransition + SlideTransition avoid per-frame setState.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                _slide.value.dx * 40,
                _slide.value.dy * 40,
              ),
              child: child,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
