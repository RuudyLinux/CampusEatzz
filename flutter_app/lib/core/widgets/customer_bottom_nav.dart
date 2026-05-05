import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/wallet/wallet_screen.dart';

enum CustomerTab { home, wallet, profile }

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({super.key, required this.current});
  final CustomerTab current;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    _NavItem('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    _NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  Widget _dest(CustomerTab tab) => switch (tab) {
        CustomerTab.home => const HomeScreen(),
        CustomerTab.wallet => const WalletScreen(),
        CustomerTab.profile => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = CustomerTab.values.indexOf(current);

    // Frosted glass nav bar matching design tokens
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.navBgDark : AppColors.navBgLight,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: List<Widget>.generate(_items.length, (i) {
                  final item = _items[i];
                  final active = i == idx;
                  final activeColor = isDark ? AppColors.primaryOnDark : AppColors.primary;
                  final mutedColor = isDark ? AppColors.darkTextDisabled : AppColors.textMuted;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (active) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(builder: (_) => _dest(CustomerTab.values[i])),
                          (route) => false,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            AnimatedScale(
                              scale: active ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                active ? item.activeIcon : item.icon,
                                size: 22,
                                color: active ? activeColor : mutedColor,
                                shadows: active
                                    ? <Shadow>[
                                        Shadow(
                                          color: (isDark ? AppColors.accentGlowDark : AppColors.accentGlowLight),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: AppTypography.badge.copyWith(
                                color: active ? activeColor : mutedColor,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
