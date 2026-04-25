import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_backdrop.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/models/canteen_admin_session.dart';
import '../../data/services/app_preferences.dart';
import '../../data/services/canteen_admin_service.dart';

class CanteenAdminLoginScreen extends StatefulWidget {
  const CanteenAdminLoginScreen({
    super.key,
    required this.onLoggedIn,
  });

  final ValueChanged<CanteenAdminSession> onLoggedIn;

  @override
  State<CanteenAdminLoginScreen> createState() =>
      _CanteenAdminLoginScreenState();
}

class _CanteenAdminLoginScreenState extends State<CanteenAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CanteenAdminService>();
      final prefs = context.read<AppPreferences>();

      final session = await service.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await prefs.saveCanteenAdminSession(session);
      if (!mounted) return;

      widget.onLoggedIn(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final tiny = width < 350;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: tiny ? 14 : (compact ? 16 : 20),
                vertical: compact ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedReveal(
                  delayMs: 80,
                  child: Column(
                    children: <Widget>[
                      // ── Brand mark ───────────────────────────────────────
                      AnimatedReveal(
                        delayMs: 0,
                        beginOffset: const Offset(0, -0.04),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(compact ? 12 : 14),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(compact ? 18 : 22),
                                border: Border.all(
                                  color:
                                      scheme.primary.withValues(alpha: 0.24),
                                ),
                              ),
                              child: AppLogo(size: compact ? 46 : 52),
                            ),
                            SizedBox(height: compact ? 12 : 14),
                            Text(
                              'Canteen Admin',
                              style: AppTypography.heading1.copyWith(
                                fontSize: compact ? 24 : 28,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your canteen operations',
                              style: AppTypography.bodySm.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: compact ? 20 : 28),

                      // ── Login card ───────────────────────────────────────
                      Card(
                        elevation: isDark ? 0 : 4,
                        shadowColor: AppColors.navy.withValues(alpha: 0.10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(compact ? 18 : 24),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 16 : 22,
                            compact ? 18 : 24,
                            compact ? 16 : 22,
                            compact ? 16 : 22,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Sign In',
                                  style: AppTypography.heading2.copyWith(
                                    fontSize: compact ? 18 : 20,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your admin credentials to continue',
                                  style: AppTypography.bodySm.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.textMuted,
                                  ),
                                ),
                                SizedBox(height: compact ? 16 : 20),

                                // Identifier field
                                TextFormField(
                                  controller: _identifierController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email or Username',
                                    prefixIcon:
                                        Icon(Icons.person_outline_rounded),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),
                                SizedBox(height: compact ? 10 : 12),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _hidePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() =>
                                          _hidePassword = !_hidePassword),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),

                                // Error message
                                if (_error != null &&
                                    _error!.isNotEmpty) ...<Widget>[
                                  SizedBox(height: compact ? 10 : 12),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(compact ? 10 : 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.dangerBgDark
                                          : AppColors.dangerBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                            Icons.error_outline_rounded,
                                            size: compact ? 14 : 16,
                                            color: AppColors.danger),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style:
                                                AppTypography.bodySm.copyWith(
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                SizedBox(height: compact ? 16 : 22),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _submit,
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.login_rounded,
                                            size: compact ? 18 : 20,
                                          ),
                                    label: Text(
                                      _loading
                                          ? 'Signing in…'
                                          : 'Login to Admin',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
