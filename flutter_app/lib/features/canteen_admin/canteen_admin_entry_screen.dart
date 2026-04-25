import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/canteen_admin_session.dart';
import '../../data/services/app_preferences.dart';
import 'canteen_admin_login_screen.dart';
import 'canteen_admin_shell_screen.dart';

class CanteenAdminEntryScreen extends StatefulWidget {
  const CanteenAdminEntryScreen({super.key});

  @override
  State<CanteenAdminEntryScreen> createState() => _CanteenAdminEntryScreenState();
}

class _CanteenAdminEntryScreenState extends State<CanteenAdminEntryScreen> {
  CanteenAdminSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = context.read<AppPreferences>();
    final saved = await prefs.getCanteenAdminSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _session = saved;
      _loading = false;
    });
  }

  void _onLoggedIn(CanteenAdminSession session) {
    setState(() {
      _session = session;
    });
  }

  void _onLoggedOut() {
    setState(() {
      _session = null;
    });
  }

  void _onSessionUpdated(CanteenAdminSession session) {
    setState(() {
      _session = session;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return CanteenAdminLoginScreen(onLoggedIn: _onLoggedIn);
    }

    return CanteenAdminShellScreen(
      initialSession: _session!,
      onLogout: _onLoggedOut,
      onSessionUpdated: _onSessionUpdated,
    );
  }
}
