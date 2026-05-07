import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Liquid navigation indicator with "melting" animation.
/// Slides between tab positions with slight overshoot (300ms ease-in-out).
/// Use inside a Row of tabs to animate the active indicator.
class LiquidNavIndicator extends StatefulWidget {
  const LiquidNavIndicator({
    super.key,
    required this.isActive,
    required this.itemCount,
    required this.currentIndex,
  });

  final bool isActive;
  final int itemCount;
  final int currentIndex;

  @override
  State<LiquidNavIndicator> createState() => _LiquidNavIndicatorState();
}

class _LiquidNavIndicatorState extends State<LiquidNavIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _position = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void didUpdateWidget(LiquidNavIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _position = Tween<double>(
        begin: oldWidget.currentIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        // Relative position: 0 to itemCount-1
        final fraction = _position.value / (widget.itemCount - 1);
        return Align(
          alignment: Alignment(
            (fraction * 2.0) - 1.0,
            0,
          ),
          child: child,
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Optional: Full liquid tab bar with animated indicator.
/// Manages scroll and active state internally.
class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    super.key,
    required this.tabs,
    required this.onTabChanged,
    this.initialIndex = 0,
  });

  final List<String> tabs;
  final ValueChanged<int> onTabChanged;
  final int initialIndex;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        widget.tabs.length,
        (index) => Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _currentIndex = index);
              widget.onTabChanged(index);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.tabs[index],
                    style: TextStyle(
                      fontWeight: _currentIndex == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _currentIndex == index
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_currentIndex == index)
                    LiquidNavIndicator(
                      isActive: true,
                      itemCount: widget.tabs.length,
                      currentIndex: index,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
