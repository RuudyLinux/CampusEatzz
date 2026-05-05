import 'package:flutter/material.dart';

import 'notification_bell_button.dart';

class GlobalActions extends StatelessWidget {
  const GlobalActions({super.key, this.iconColor});
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationBellButton(iconColor: iconColor),
      ],
    );
  }
}
