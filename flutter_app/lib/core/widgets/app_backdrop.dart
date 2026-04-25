import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: <Color>[AppColors.darkBg, AppColors.darkSurface, AppColors.darkBg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.backgroundGradient,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -56,
            right: -42,
            child: _orb(
              170,
              isDark
                  ? const Color(0x1AFF4E7C)
                  : const Color(0x1FB70049),
            ),
          ),
          Positioned(
            bottom: -72,
            left: -50,
            child: _orb(
              220,
              isDark
                  ? const Color(0x149A3669)
                  : const Color(0x1A6149B2),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
