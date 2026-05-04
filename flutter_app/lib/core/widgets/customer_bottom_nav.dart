import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/wallet/wallet_screen.dart';

enum CustomerTab {
  home,
  wallet,
  profile,
}

class _CustomerNavItem {
  const _CustomerNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({
    super.key,
    required this.current,
  });

  final CustomerTab current;

  static const List<_CustomerNavItem> _items = <_CustomerNavItem>[
    _CustomerNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _CustomerNavItem(
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    _CustomerNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  Widget _destinationForTab(CustomerTab tab) {
    switch (tab) {
      case CustomerTab.home:
        return const HomeScreen();
      case CustomerTab.wallet:
        return const WalletScreen();
      case CustomerTab.profile:
        return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = CustomerTab.values.indexOf(current);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                // Glass fill: white 45% light / darkCard 55% dark
                color: isDark
                    ? AppColors.darkCard.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  // Top/left bevel — white 20%
                  color: isDark
                      ? AppColors.glassBevelBottom
                      : AppColors.glassBevelTop,
                  width: 1,
                ),
                boxShadow: const <BoxShadow>[
                  // Ambient occlusion — spec: 0 20px 40px rgba(0,0,0,0.04)
                  BoxShadow(
                    color: AppColors.glassShadow,
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: Offset(0, 20),
                  ),
                  BoxShadow(
                    color: AppColors.shadowMintTint,
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List<Widget>.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = index == currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (selected) return;
                        final destination =
                            _destinationForTab(CustomerTab.values[index]);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(builder: (_) => destination),
                          (route) => false,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          // Selected pill: mint at 15% — glass highlight
                          color: selected
                              ? (isDark
                                  ? AppColors.primaryOnDark.withValues(alpha: 0.18)
                                  : AppColors.primary.withValues(alpha: 0.12))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(32),
                          border: selected
                              ? Border.all(
                                  color: isDark
                                      ? AppColors.primaryOnDark
                                          .withValues(alpha: 0.25)
                                      : AppColors.primary.withValues(alpha: 0.20),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 20,
                              color: selected
                                  ? (isDark
                                      ? AppColors.primaryOnDark
                                      : AppColors.primary)
                                  : (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: selected
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        item.label,
                                        style: AppTypography.labelSm.copyWith(
                                          color: isDark
                                              ? AppColors.primaryOnDark
                                              : AppColors.primary,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
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
