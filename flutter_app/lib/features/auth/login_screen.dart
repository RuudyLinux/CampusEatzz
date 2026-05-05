import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_backdrop.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../state/auth_provider.dart';
import '../canteen_admin/canteen_admin_entry_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.requestOtp(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Unable to send OTP.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OtpScreen()),
    );
  }

  void _openCanteenAdminLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CanteenAdminEntryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedReveal(
                  delayMs: 80,
                  child: Column(
                    children: <Widget>[
                      // ── Brand mark ──────────────────────────────────────────
                      AnimatedReveal(
                        delayMs: 0,
                        beginOffset: const Offset(0, -0.04),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.24),
                                ),
                              ),
                              child: const AppLogo(size: 52),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'CampusEatzz',
                              style: AppTypography.heading1.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your campus food, made easy',
                              style: AppTypography.bodySm.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Login card ──────────────────────────────────────────
                      Card(
                        elevation: isDark ? 0 : 4,
                        shadowColor: AppColors.navy.withValues(alpha: 0.10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Sign In',
                                  style: AppTypography.heading2.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'OTP verification required for secure access',
                                  style: AppTypography.bodySm.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Students: use enrollment number | Faculty: use email',
                                  style: AppTypography.bodySm.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.textMuted,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Identifier field
                                TextFormField(
                                  controller: _identifierController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email or Enrollment Number',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                    hintText: 'example@college.edu or 202307XXXX',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),

                                const SizedBox(height: 12),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _hidePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!auth.isLoading) _submit();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                          () => _hidePassword = !_hidePassword),
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

                                const SizedBox(height: 22),

                                // Submit button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: auth.isLoading ? null : _submit,
                                    icon: auth.isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.arrow_forward_rounded),
                                    label: Text(
                                      auth.isLoading
                                          ? 'Sending OTP…'
                                          : 'Continue with OTP',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Admin login ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: <Widget>[
                            Text(
                              'Are you a canteen owner?',
                              style: AppTypography.bodySm.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openCanteenAdminLogin,
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Canteen Admin Login'),
                              ),
                            ),
                          ],
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
