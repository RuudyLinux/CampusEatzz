import 'package:flutter/material.dart';

import '../../data/models/app_notification.dart';
import '../feedback/feedback_screen.dart';
import '../home/home_screen.dart';
import '../menu/menu_screen.dart';
import '../orders/order_details_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class NotificationNavigation {
  static Future<void> openAction(
    BuildContext context,
    NotificationAction action,
  ) async {
    switch (action.action) {
      case 'order_details':
        final ref = (action.orderRef ?? action.orderId?.toString() ?? '').trim();
        if (ref.isEmpty) {
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailsScreen(orderRef: ref),
          ),
        );
        return;

      case 'feedback':
        final ref = (action.orderRef ?? action.orderId?.toString() ?? '').trim();
        if (ref.isEmpty) {
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FeedbackScreen(orderRef: ref),
          ),
        );
        return;

      case 'menu':
        final canteenId = action.canteenId ?? 0;
        if (canteenId <= 0) {
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MenuScreen(
              canteenId: canteenId,
              canteenName: 'Canteen #$canteenId',
            ),
          ),
        );
        return;

      case 'wallet':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
        );
        return;

      case 'profile':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        );
        return;

      case 'home':
      default:
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
    }
  }
}
