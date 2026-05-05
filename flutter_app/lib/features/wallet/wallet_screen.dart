import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_async_view.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/global_actions.dart';
import '../../state/auth_provider.dart';
import '../../state/wallet_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<AuthProvider>().session;
      if (session != null) {
        context.read<WalletProvider>().load(session.identifier);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _recharge() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum recharge is ₹10.')));
      return;
    }

    final session = context.read<AuthProvider>().session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first.')));
      return;
    }

    final ok = await context.read<WalletProvider>().recharge(
          identifier: session.identifier,
          amount: amount,
        );
    if (!mounted) return;

    if (ok) {
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Money added successfully!')));
    } else {
      final message =
          context.read<WalletProvider>().error ?? 'Unable to recharge wallet.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.wallet),
      body: Column(
        children: <Widget>[
          const GradientHeader(
            title: 'My Wallet',
            subtitle: 'Balance & transactions',
            trailing: GlobalActions(),
          ),
          Expanded(
            child: _isSessionExpired(wallet.error)
                ? _SessionExpiredView(
                    onLogIn: () => context.read<AuthProvider>().logout(),
                  )
                : AppAsyncView(
              isLoading: wallet.isLoading,
              error: wallet.error,
              onRetry: () {
                final session = context.read<AuthProvider>().session;
                if (session != null) {
                  context.read<WalletProvider>().load(session.identifier);
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  // ── Balance card ──────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 60,
                    child: _BalanceCard(
                        balance: wallet.wallet.balance, isDark: isDark),
                  ),
                  const SizedBox(height: 14),

                  // ── Add money ─────────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 130,
                    child: _AddMoneyCard(
                      controller: _amountController,
                      isDark: isDark,
                      onRecharge: _recharge,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Transactions ──────────────────────────────────────
                  AnimatedReveal(
                    delayMs: 200,
                    child: _TransactionsCard(
                      transactions: wallet.transactions,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Balance Card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.isDark});

  final double balance;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkHeaderGradient : AppColors.walletGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -24,
            right: -12,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Campus Wallet',
                    style: AppTypography.label
                        .copyWith(color: Colors.white.withValues(alpha: 0.80)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                formatInr(balance),
                style: AppTypography.priceLg.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Available Balance',
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.70)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Money Card ────────────────────────────────────────────────────────────

class _AddMoneyCard extends StatelessWidget {
  const _AddMoneyCard({
    required this.controller,
    required this.isDark,
    required this.onRecharge,
  });

  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Add Money',
              style: AppTypography.heading3.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Quick amounts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[100, 200, 500].map((value) {
                return OutlinedButton(
                  onPressed: () => controller.text = '$value',
                  child: Text('₹$value'),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custom Amount',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRecharge,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add Money'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transactions Card ─────────────────────────────────────────────────────────

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard(
      {required this.transactions, required this.isDark});

  final List<dynamic> transactions;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Recent Transactions',
              style: AppTypography.heading3.copyWith(
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (transactions.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_outlined,
                title: 'No Transactions',
                subtitle: 'Your transaction history will appear here.',
                compact: true,
              )
            else
              ...transactions.asMap().entries.map((entry) {
                final tx = entry.value;
                final isCredit = tx.isCredit as bool;
                return AnimatedReveal(
                  delayMs: 220 + (entry.key * 30),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isCredit
                                ? (isDark
                                    ? AppColors.successBgDark
                                    : AppColors.successBg)
                                : (isDark
                                    ? AppColors.dangerBgDark
                                    : AppColors.dangerBg),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCredit
                                ? Icons.add_rounded
                                : Icons.shopping_bag_outlined,
                            color: isCredit
                                ? AppColors.success
                                : AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                tx.description as String,
                                style: AppTypography.label.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDateTime(tx.createdAt as DateTime),
                                style: AppTypography.caption.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isCredit ? '+' : '-'}${formatInr((tx.amount as double).abs())}',
                          style: AppTypography.priceSm.copyWith(
                            color: isCredit
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Session expired helpers ───────────────────────────────────────────────────

bool _isSessionExpired(String? error) =>
    error != null && error.contains('session_expired');

class _SessionExpiredView extends StatelessWidget {
  const _SessionExpiredView({required this.onLogIn});

  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_clock_rounded,
              size: 64,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
            const SizedBox(height: 20),
            Text(
              'Session Expired',
              style: AppTypography.heading2.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your login session has expired. Please log in again to access your wallet.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Log In Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
