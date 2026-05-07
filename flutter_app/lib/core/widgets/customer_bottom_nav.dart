import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/wallet/wallet_screen.dart';

enum CustomerTab { home, wallet, profile }

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon, this.color);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
}

class CustomerBottomNav extends StatefulWidget {
  const CustomerBottomNav({super.key, required this.current});
  final CustomerTab current;

  @override
  State<CustomerBottomNav> createState() => _CustomerBottomNavState();
}

class _CustomerBottomNavState extends State<CustomerBottomNav>
    with SingleTickerProviderStateMixin {
  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Home', Icons.home_outlined, Icons.home_rounded, AppColors.tabHome),
    _NavItem(
      'Wallet',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      AppColors.tabWallet,
    ),
    _NavItem(
      'Profile',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      AppColors.tabProfile,
    ),
  ];

  late AnimationController _pillController;
  late Animation<double> _pillPosition;
  int _prevIndex = 0;

  // Per-item press tracking
  final List<bool> _pressed = List<bool>.filled(3, false);

  Widget _dest(CustomerTab tab) => switch (tab) {
        CustomerTab.home => const HomeScreen(),
        CustomerTab.wallet => const WalletScreen(),
        CustomerTab.profile => const ProfileScreen(),
      };

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.current.index;
    _pillController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _pillPosition = Tween<double>(
      begin: widget.current.index.toDouble(),
      end: widget.current.index.toDouble(),
    ).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void didUpdateWidget(CustomerBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _pillPosition = Tween<double>(
        begin: _prevIndex.toDouble(),
        end: widget.current.index.toDouble(),
      ).animate(
        CurvedAnimation(parent: _pillController, curve: Curves.easeInOutBack),
      );
      _prevIndex = widget.current.index;
      _pillController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = widget.current.index;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final extraHeight = (textScale - 1.0).clamp(0.0, 1.0);
    final navHeight = 62.0 + (extraHeight * 10.0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.navBgDark : AppColors.navBgLight,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop,
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: navHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _items.length;
                  return Stack(
                    children: <Widget>[
                      // Sliding liquid pill background
                      AnimatedBuilder(
                        animation: _pillPosition,
                        builder: (context, child) {
                          final pillW = itemWidth * 0.60;
                          final center = itemWidth * (_pillPosition.value + 0.5);
                          final left = center - pillW / 2;

                          return Positioned(
                            left: left.clamp(4.0, constraints.maxWidth - pillW - 4),
                            top: 8,
                            bottom: 8,
                            width: pillW,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? <Color>[
                                          AppColors.darkGlassStrong,
                                          AppColors.darkGlassMid,
                                        ]
                                      : <Color>[
                                          _items[idx].color.withValues(alpha: 0.13),
                                          _items[idx].color.withValues(alpha: 0.07),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkGlassBevelTop
                                      : _items[idx].color.withValues(alpha: 0.30),
                                  width: 1.0,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: (isDark
                                            ? AppColors.accentGlowDark
                                            : _items[idx].color)
                                        .withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Tab items
                      Row(
                        children: List<Widget>.generate(_items.length, (i) {
                          final item = _items[i];
                          final active = i == idx;
                          final mutedColor = isDark
                              ? AppColors.darkTextDisabled
                              : AppColors.textMuted;
                          final itemActiveColor =
                              isDark ? AppColors.primaryOnDark : item.color;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) =>
                                  setState(() => _pressed[i] = true),
                              onTapUp: (_) =>
                                  setState(() => _pressed[i] = false),
                              onTapCancel: () =>
                                  setState(() => _pressed[i] = false),
                              onTap: () {
                                setState(() => _pressed[i] = false);
                                if (active) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _dest(CustomerTab.values[i]),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: AnimatedScale(
                                scale: _pressed[i] ? 0.92 : 1.0,
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    AnimatedScale(
                                      scale: active ? 1.12 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutBack,
                                      child: Icon(
                                        active ? item.activeIcon : item.icon,
                                        size: 22,
                                        color: active
                                            ? itemActiveColor
                                            : mutedColor,
                                        shadows: active
                                            ? <Shadow>[
                                                Shadow(
                                                  color: (isDark
                                                          ? AppColors
                                                              .accentGlowDark
                                                          : item.color)
                                                      .withValues(alpha: 0.50),
                                                  blurRadius: 12,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      style: AppTypography.badge.copyWith(
                                        color: active
                                            ? itemActiveColor
                                            : mutedColor,
                                        fontWeight: active
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        fontSize: active ? 10.5 : 10,
                                      ),
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
