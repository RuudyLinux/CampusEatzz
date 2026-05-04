import 'package:flutter/material.dart';

/// High-gloss glass button with physical weight press effect.
/// Scales to 96% and reduces shadow on press (150ms ease-out).
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPress() {
    if (!widget.enabled || widget.isLoading) return;
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _onPress(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: widget.enabled && !widget.isLoading
                ? _onPress
                : null,
            icon: widget.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : Colors.white,
                      ),
                    ),
                  )
                : (widget.icon != null ? Icon(widget.icon) : const SizedBox.shrink()),
            label: Text(widget.label),
            style: theme.elevatedButtonTheme.style,
          ),
        ),
      ),
    );
  }
}

/// Outlined glass button — mint border, transparent fill.
class GlassOutlinedButton extends StatefulWidget {
  const GlassOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool enabled;

  @override
  State<GlassOutlinedButton> createState() => _GlassOutlinedButtonState();
}

class _GlassOutlinedButtonState extends State<GlassOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPress() {
    if (!widget.enabled) return;
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _onPress(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: widget.enabled ? _onPress : null,
            icon: widget.icon != null ? Icon(widget.icon) : const SizedBox.shrink(),
            label: Text(widget.label),
            style: theme.outlinedButtonTheme.style,
          ),
        ),
      ),
    );
  }
}

/// Text glass button — minimal, no background.
class GlassTextButton extends StatefulWidget {
  const GlassTextButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool enabled;

  @override
  State<GlassTextButton> createState() => _GlassTextButtonState();
}

class _GlassTextButtonState extends State<GlassTextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPress() {
    if (!widget.enabled) return;
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _onPress(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          height: 50,
          child: TextButton.icon(
            onPressed: widget.enabled ? _onPress : null,
            icon: widget.icon != null ? Icon(widget.icon) : const SizedBox.shrink(),
            label: Text(widget.label),
            style: theme.textButtonTheme.style,
          ),
        ),
      ),
    );
  }
}
