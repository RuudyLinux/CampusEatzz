import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_backdrop.dart';
import '../../state/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final _focusNodes = List<FocusNode>.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((e) => e.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter all 6 digits.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(_otp);

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'OTP verification failed.')),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await authProvider.resendOtp();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'OTP resent successfully.'
              : (authProvider.error ?? 'Unable to resend OTP.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // Guard: no pending session
    if (auth.pendingIdentifier.trim().isEmpty) {
      return Scaffold(
        body: AppBackdrop(
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded,
                        size: 40, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Session Expired',
                      style: AppTypography.heading3.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please request OTP from the login screen.',
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Go to Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedReveal(
                  delayMs: 80,
                  child: Column(
                    children: <Widget>[
                      // ── Icon header ────────────────────────────────────────
                      AnimatedReveal(
                        delayMs: 0,
                        beginOffset: const Offset(0, -0.04),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color:
                                      scheme.primary.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Icon(
                                Icons.mark_email_read_outlined,
                                size: 44,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Check Your Email',
                              style: AppTypography.heading1.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code sent to ${auth.pendingIdentifier}',
                              style: AppTypography.bodySm.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── OTP card ───────────────────────────────────────────
                      Card(
                        elevation: isDark ? 0 : 4,
                        shadowColor: AppColors.navy.withValues(alpha: 0.10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Enter 6-Digit Code',
                                style: AppTypography.heading3.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // OTP boxes
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List<Widget>.generate(6, (index) {
                                  return _OtpBox(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      }
                                      if (value.isEmpty && index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }
                                    },
                                  );
                                }),
                              ),

                              const SizedBox(height: 20),

                              // Verify button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: auth.isLoading ? null : _verify,
                                  icon: auth.isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline_rounded),
                                  label: Text(
                                    auth.isLoading
                                        ? 'Verifying…'
                                        : 'Verify OTP',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend + back
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "Didn't receive it? ",
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: auth.isLoading ? null : _resend,
                            child: const Text('Resend'),
                          ),
                        ],
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

/// A single OTP digit box.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 44,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: AppTypography.heading3.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : AppColors.bgSoft,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
