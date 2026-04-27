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

    // Dark pill nav (screenshot style) — light variant in dark mode stays readable
    final navBg = isDark ? AppColors.darkCardRaised : AppColors.textPrimary;
    final unselectedColor = isDark
        ? AppColors.darkTextMuted
        : Colors.white.withValues(alpha: 0.55);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(40),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.30),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 20,
                          color: selected ? AppColors.primaryOnDark : unselectedColor,
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
                                      color: AppColors.primaryOnDark,
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
    );
  }
}
