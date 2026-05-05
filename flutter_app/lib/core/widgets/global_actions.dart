import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notification_bell_button.dart';
import '../../features/cart/cart_screen.dart';
import '../../state/cart_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class GlobalActions extends StatelessWidget {
  const GlobalActions({super.key, this.iconColor});
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final effectiveColor = iconColor ?? IconTheme.of(context).color ?? Colors.white;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.shopping_bag_outlined, color: effectiveColor),
              if (cart.totalItems > 0)
                Positioned(
                  right: -4,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cart.totalItems.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        NotificationBellButton(iconColor: iconColor),
      ],
    );
  }
}
