import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/api_client.dart';
import 'data/services/app_preferences.dart';
import 'data/services/auth_service.dart';
import 'data/services/canteen_service.dart';
import 'data/services/canteen_admin_service.dart';
import 'data/services/chat_service.dart';
import 'data/services/customer_service.dart';
import 'data/services/push_notification_service.dart';
import 'data/services/recommendation_service.dart';
import 'features/auth/bootstrap_screen.dart';
import 'features/notifications/notification_navigation.dart';
import 'state/auth_provider.dart';
import 'state/canteen_provider.dart';
import 'state/cart_provider.dart';
import 'state/chat_provider.dart';
import 'state/notification_provider.dart';
import 'state/orders_provider.dart';
import 'state/recommendation_provider.dart';
import 'state/wallet_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusEatzzApp());
}

class CampusEatzzApp extends StatelessWidget {
  const CampusEatzzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppPreferences>(create: (_) => AppPreferences()),
        Provider<ApiClient>(create: (context) => ApiClient(context.read<AppPreferences>())),
        Provider<AuthService>(create: (context) => AuthService(context.read<ApiClient>())),
        Provider<CanteenService>(create: (context) => CanteenService(context.read<ApiClient>())),
        Provider<CanteenAdminService>(create: (context) => CanteenAdminService(context.read<ApiClient>())),
        Provider<CustomerService>(create: (context) => CustomerService(context.read<ApiClient>())),
        Provider<ChatService>(create: (context) => ChatService(context.read<ApiClient>())),
        Provider<RecommendationService>(
          create: (context) => RecommendationService(context.read<ApiClient>()),
        ),
        Provider<PushNotificationService>(
          create: (context) => PushNotificationService(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthService>(), context.read<AppPreferences>()),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (context) => CartProvider(context.read<AppPreferences>()),
        ),
        ChangeNotifierProvider<CanteenProvider>(
          create: (context) => CanteenProvider(context.read<CanteenService>()),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (context) => WalletProvider(context.read<CustomerService>(), context.read<AppPreferences>()),
        ),
        ChangeNotifierProvider<OrdersProvider>(
          create: (context) => OrdersProvider(context.read<CustomerService>()),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (context) => ChatProvider(context.read<ChatService>()),
        ),
        ChangeNotifierProvider<RecommendationProvider>(
          create: (context) =>
              RecommendationProvider(context.read<RecommendationService>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(context.read<PushNotificationService>()),
          update: (context, auth, provider) {
            final resolved = provider ?? NotificationProvider(context.read<PushNotificationService>());
            resolved.syncSession(auth.session);
            return resolved;
          },
        ),
      ],
      child: MaterialApp(
        title: 'CampusEatzz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        darkTheme: AppTheme.buildDark(),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          return _NotificationActionHost(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const BootstrapScreen(),
      ),
    );
  }
}

class _NotificationActionHost extends StatefulWidget {
  const _NotificationActionHost({required this.child});

  final Widget child;

  @override
  State<_NotificationActionHost> createState() => _NotificationActionHostState();
}

class _NotificationActionHostState extends State<_NotificationActionHost> {
  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final pendingAction = notifications.consumePendingAction();
      if (pendingAction != null) {
        NotificationNavigation.openAction(context, pendingAction);
      }

      final foregroundEvent = notifications.consumeForegroundEvent();
      if (foregroundEvent != null) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text('${foregroundEvent.title}: ${foregroundEvent.body}'),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () {
                NotificationNavigation.openAction(context, foregroundEvent.action);
              },
            ),
          ),
        );
      }
    });

    return widget.child;
  }
}
