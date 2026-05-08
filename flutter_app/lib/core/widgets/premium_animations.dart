import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

// ── Animated Success Checkmark ────────────────────────────────────────────────

class AnimatedSuccessCheck extends StatefulWidget {
  const AnimatedSuccessCheck({
    super.key,
    this.size = 80,
    this.color = AppColors.success,
    this.bgColor = AppColors.successBg,
    this.delayMs = 0,
    this.onComplete,
  });

  final double size;
  final Color color;
  final Color bgColor;
  final int delayMs;
  final VoidCallback? onComplete;

  @override
  State<AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _circlePop;
  late Animation<double> _checkDraw;
  late Animation<double> _ringPulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _circlePop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    ));

    _checkDraw = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _ringPulse = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );

    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _ctrl.forward().then((_) => widget.onComplete?.call());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring
              if (_ringPulse.value > 0)
                Opacity(
                  opacity: (1 - _ringPulse.value).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + _ringPulse.value * 0.5,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              // Main circle
              Transform.scale(
                scale: _circlePop.value,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    painter: _CheckPainter(
                      progress: _checkDraw.value,
                      color: widget.color,
                      strokeWidth: s * 0.07,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.20;

    // Check: short left leg then long right leg
    final p1 = Offset(cx - r * 0.8, cy);
    final p2 = Offset(cx - r * 0.1, cy + r * 0.6);
    final p3 = Offset(cx + r * 1.1, cy - r * 0.7);

    final totalLen = (p2 - p1).distance + (p3 - p2).distance;
    final drawn = totalLen * progress;
    final leg1 = (p2 - p1).distance;

    final path = Path()..moveTo(p1.dx, p1.dy);

    if (drawn <= leg1) {
      final t = drawn / leg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - leg1) / (totalLen - leg1);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}


// ── Payment Processing Animation ──────────────────────────────────────────────

class PaymentProcessingWidget extends StatelessWidget {
  const PaymentProcessingWidget({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.primaryOnDark : AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                    color.withValues(alpha: 0.25)),
              ),
              Icon(Icons.lock_rounded, size: 28, color: color)
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                      begin: 0.95,
                      end: 1.05,
                      duration: 800.ms,
                      curve: Curves.easeInOut)
                  .then()
                  .scaleXY(begin: 1.05, end: 0.95, duration: 800.ms),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Processing Payment…',
          style: AppTypography.heading3.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Please wait, do not close this screen',
          style: AppTypography.caption.copyWith(
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        _ProcessingDots(color: color),
      ],
    );
  }
}

class _ProcessingDots extends StatelessWidget {
  const _ProcessingDots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(
                begin: 0.5,
                end: 1.0,
                delay: (i * 180).ms,
                duration: 500.ms,
                curve: Curves.easeOut)
            .then()
            .scaleXY(begin: 1.0, end: 0.5, duration: 500.ms);
      }),
    );
  }
}

// ── Order Progress Timeline ───────────────────────────────────────────────────

class OrderProgressTimeline extends StatelessWidget {
  const OrderProgressTimeline({
    super.key,
    required this.currentStatus,
    required this.isDark,
    this.animateIn = true,
  });

  final String currentStatus;
  final bool isDark;
  final bool animateIn;

  static const _stages = [
    (icon: Icons.receipt_long_rounded, label: 'Placed'),
    (icon: Icons.restaurant_rounded, label: 'Preparing'),
    (icon: Icons.check_circle_rounded, label: 'Ready'),
    (icon: Icons.done_all_rounded, label: 'Completed'),
  ];

  static const _statusMap = {
    'pending': 0,
    'confirmed': 1,
    'preparing': 1,
    'ready': 2,
    'completed': 3,
    'delivered': 3,
  };

  @override
  Widget build(BuildContext context) {
    final step =
        _statusMap[currentStatus.toLowerCase()] ?? 0;
    final activeColor =
        isDark ? AppColors.primaryOnDark : AppColors.primary;

    return Row(
      children: List.generate(_stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final lineStep = i ~/ 2;
          final filled = lineStep < step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 3,
              decoration: BoxDecoration(
                color: filled
                    ? activeColor
                    : (isDark ? AppColors.darkBorder : AppColors.divider),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }

        final idx = i ~/ 2;
        final done = idx < step;
        final active = idx == step;
        final stage = _stages[idx];

        Widget dot = AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: active ? 44 : 36,
          height: active ? 44 : 36,
          decoration: BoxDecoration(
            color: done || active
                ? activeColor
                : (isDark ? AppColors.darkCard : AppColors.surfaceRaised),
            shape: BoxShape.circle,
            border: Border.all(
              color: done || active
                  ? activeColor
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: active ? 2.5 : 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Icon(
            done ? Icons.check_rounded : stage.icon,
            size: active ? 22 : 18,
            color: done || active
                ? Colors.white
                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
          ),
        );

        if (animateIn) {
          dot = dot
              .animate(delay: (idx * 120).ms)
              .scaleXY(begin: 0.6, end: 1.0, duration: 350.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 200.ms);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(height: 6),
            Text(
              stage.label,
              style: AppTypography.caption.copyWith(
                color: done || active
                    ? activeColor
                    : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Press Scale Button ─────────────────────────────────────────────────────────

class PressScaleButton extends StatefulWidget {
  const PressScaleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  @override
  State<PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<PressScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── Add-to-Cart Floating Animation ────────────────────────────────────────────

class CartAddFeedback extends StatefulWidget {
  const CartAddFeedback({
    super.key,
    required this.child,
    required this.isDark,
  });

  final Widget child;
  final bool isDark;

  static CartAddFeedbackState? of(BuildContext context) =>
      context.findAncestorStateOfType<CartAddFeedbackState>();

  @override
  CartAddFeedbackState createState() => CartAddFeedbackState();
}

class CartAddFeedbackState extends State<CartAddFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _y;
  late Animation<double> _scale;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _y = Tween<double>(begin: 0, end: -48).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 50),
    ]).animate(_ctrl);
  }

  void trigger() {
    setState(() => _visible = true);
    _ctrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDark ? AppColors.primaryOnDark : AppColors.primary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_visible)
          Positioned(
            top: -8,
            right: 0,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _y.value),
                child: Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: _fade.value.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            'Added!',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Animated Cart Badge ────────────────────────────────────────────────────────

class AnimatedCartBadge extends StatelessWidget {
  const AnimatedCartBadge({
    super.key,
    required this.count,
    required this.child,
  });

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            top: -6,
            right: -6,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Container(
                key: ValueKey(count),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pulse Loader (replaces CircularProgressIndicator) ─────────────────────────

class PulseLoader extends StatelessWidget {
  const PulseLoader({
    super.key,
    this.color,
    this.size = 48,
  });

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.primaryOnDark : AppColors.primary);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.12),
            ),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat())
              .scaleXY(begin: 0.8, end: 1.2, duration: 900.ms, curve: Curves.easeInOut)
              .fadeOut(begin: 0.6, duration: 900.ms),
          Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat())
              .scaleXY(
                  begin: 0.9,
                  end: 1.1,
                  duration: 700.ms,
                  curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

// ── Slide Fade Page Route ──────────────────────────────────────────────────────

class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  SlideFadeRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, anim, secAnim, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));

            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(position: slide, child: child),
            );
          },
        );

  final Widget page;
}

// ── Money Added Overlay ────────────────────────────────────────────────────────

/// Call via [showMoneyAddedOverlay]. Auto-dismisses after 2.2 seconds.
Future<void> showMoneyAddedOverlay(
    BuildContext context, double amount, bool isDark) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child),
    ),
    pageBuilder: (ctx, _, __) => _MoneyAddedDialog(amount: amount, isDark: isDark),
  );
}

class _MoneyAddedDialog extends StatefulWidget {
  const _MoneyAddedDialog({required this.amount, required this.isDark});
  final double amount;
  final bool isDark;

  @override
  State<_MoneyAddedDialog> createState() => _MoneyAddedDialogState();
}

class _MoneyAddedDialogState extends State<_MoneyAddedDialog> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.success;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1a1a2e) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedSuccessCheck(
                size: 72,
                color: color,
                bgColor: AppColors.successBg,
                delayMs: 0,
              ),
              const SizedBox(height: 20),
              Text(
                'Money Added!',
                style: AppTypography.heading2.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${amount.toStringAsFixed(0)} added to your wallet',
                style: AppTypography.body.copyWith(color: AppColors.success),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get amount => widget.amount;
}

// ── Order Cancelled Overlay ────────────────────────────────────────────────────

/// Call via [showOrderCancelledOverlay]. Auto-dismisses after 2.2 seconds.
Future<void> showOrderCancelledOverlay(
    BuildContext context, String message, bool isDark) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child),
    ),
    pageBuilder: (ctx, _, __) =>
        _OrderCancelledDialog(message: message, isDark: isDark),
  );
}

class _OrderCancelledDialog extends StatefulWidget {
  const _OrderCancelledDialog(
      {required this.message, required this.isDark});
  final String message;
  final bool isDark;

  @override
  State<_OrderCancelledDialog> createState() => _OrderCancelledDialogState();
}

class _OrderCancelledDialogState extends State<_OrderCancelledDialog> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1a1a2e) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // X mark in circle
              _CancelCheckmark(isDark: widget.isDark),
              const SizedBox(height: 20),
              Text(
                'Order Cancelled',
                style: AppTypography.heading2.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.message,
                style: AppTypography.body.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextMuted
                      : AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelCheckmark extends StatefulWidget {
  const _CancelCheckmark({required this.isDark});
  final bool isDark;

  @override
  State<_CancelCheckmark> createState() => _CancelCheckmarkState();
}

class _CancelCheckmarkState extends State<_CancelCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _circle;
  late Animation<double> _icon;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _circle = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.12), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _icon = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOutBack)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _circle.value,
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.dangerBg,
            shape: BoxShape.circle,
          ),
          child: Transform.scale(
            scale: _icon.value,
            child: const Icon(Icons.close_rounded,
                color: AppColors.danger, size: 38),
          ),
        ),
      ),
    );
  }
}
