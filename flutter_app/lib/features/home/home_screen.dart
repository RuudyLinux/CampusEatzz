import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_async_view.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/customer_bottom_nav.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/network_food_image.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/canteen.dart';
import '../../state/canteen_provider.dart';
import '../contact/contact_us_screen.dart';
import '../menu/menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CanteenProvider>().loadCanteens();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canteenState = context.watch<CanteenProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final greeting = _greeting();

    return Scaffold(
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.home),
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'CampusEatzz',
            subtitle: greeting,
            trailing: const NotificationBellButton(),
          ),
          Expanded(
            child: AppAsyncView(
              isLoading: canteenState.loadingCanteens,
              error: canteenState.error,
              onRetry: () => context.read<CanteenProvider>().loadCanteens(),
              skeleton: const _HomeSkeleton(),
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<CanteenProvider>().loadCanteens(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: <Widget>[
                    AnimatedReveal(
                        delayMs: 60, child: _HeroBanner(isDark: isDark)),
                    const SizedBox(height: 24),
                    AnimatedReveal(
                        delayMs: 130, child: _FeatureRow(isDark: isDark)),
                    const SizedBox(height: 24),
                    AnimatedReveal(
                      delayMs: 200,
                      child: _CanteenSection(
                        canteens: canteenState.canteens,
                        isDark: isDark,
                        onTap: _openMenu,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedReveal(
                        delayMs: 270,
                        child: _TrendingSection(isDark: isDark)),
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delayMs: 340,
                      child: _ContactUsPromptSection(
                        isDark: isDark,
                        onTap: _openContactUs,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMenu(Canteen canteen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MenuScreen(canteenId: canteen.id, canteenName: canteen.name),
      ),
    );
  }

  void _openContactUs() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContactUsScreen()),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkHeaderGradient : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Fresh, Tasty & Made With Love',
                style: AppTypography.heading3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Order your favorite meals from campus canteens — fast, easy, and cashless.',
                style: AppTypography.bodySm.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.bolt_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'Skip the queue — order ahead',
                      style: AppTypography.labelSm
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Why CampusEatzz?',
          style: AppTypography.heading3.copyWith(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _FeatureCard(
              icon: Icons.timer_rounded,
              title: 'Fast',
              subtitle: 'Quick service',
              color: AppColors.tabHome,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _FeatureCard(
              icon: Icons.eco_rounded,
              title: 'Fresh',
              subtitle: 'Quality meals',
              color: AppColors.tabWallet,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _FeatureCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Cashless',
              subtitle: 'Pay via wallet',
              color: AppColors.tabCart,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.label.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Canteen Section ───────────────────────────────────────────────────────────

class _CanteenSection extends StatelessWidget {
  const _CanteenSection({
    required this.canteens,
    required this.isDark,
    required this.onTap,
  });

  final List<Canteen> canteens;
  final bool isDark;
  final void Function(Canteen) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Our Canteens',
                style: AppTypography.heading3.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${canteens.length} available',
              style: AppTypography.label.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (canteens.isEmpty)
          AppEmptyState(
            icon: Icons.storefront_outlined,
            title: 'No Canteens Yet',
            subtitle:
                'Check back soon — canteens will appear here once available.',
            compact: true,
          )
        else
          ...canteens.map(
            (canteen) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CanteenCard(
                  canteen: canteen, isDark: isDark, onTap: onTap),
            ),
          ),
      ],
    );
  }
}

class _CanteenCard extends StatelessWidget {
  const _CanteenCard({
    required this.canteen,
    required this.isDark,
    required this.onTap,
  });

  final Canteen canteen;
  final bool isDark;
  final void Function(Canteen) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(canteen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image
            if (canteen.imageUrl.isNotEmpty)
              NetworkFoodImage(
                imageUrl: canteen.imageUrl,
                fallbackAsset: 'assets/images/Restaurants.jpg',
                height: 190,
                borderRadius: BorderRadius.zero,
              )
            else
              Container(
                width: double.infinity,
                height: 190,
                color: isDark
                    ? AppColors.darkBg.withValues(alpha: 0.5)
                    : AppColors.bg,
                child: Icon(Icons.storefront_rounded,
                    size: 60,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.textMuted),
              ),
            // Status pill
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.circle, size: 6, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Open',
                      style: AppTypography.labelSm
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    canteen.name,
                    style: AppTypography.heading3.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canteen.description.isEmpty
                        ? 'Fresh campus meals and snacks'
                        : canteen.description,
                    style: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.primaryOnDark
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'View Menu',
                        style: AppTypography.label.copyWith(
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.primaryOnDark
                            : AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trending Section ──────────────────────────────────────────────────────────

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.isDark});

  final bool isDark;

  static const List<Map<String, String>> _items = <Map<String, String>>[
    {
      'name': 'Masala Tea',
      'price': '₹15',
      'image': 'assets/images/Iced_Latte.jpg'
    },
    {
      'name': 'Veg Sandwich',
      'price': '₹40',
      'image': 'assets/images/Caesar_Salad.jpg'
    },
    {
      'name': 'Samosa',
      'price': '₹20',
      'image': 'assets/images/Spring_Rolls.jpg'
    },
    {
      'name': 'Cheese Pizza',
      'price': '₹80',
      'image': 'assets/images/Margherita_Pizza.jpg'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Trending Dishes',
          style: AppTypography.heading3.copyWith(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final item = _items[index];
              return SizedBox(
                width: 160,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Image.asset(
                        item['image']!,
                        width: double.infinity,
                        height: 115,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item['name']!,
                              style: AppTypography.label.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['price']!,
                              style: AppTypography.priceSm.copyWith(
                                color: isDark
                                    ? AppColors.primaryOnDark
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactUsPromptSection extends StatelessWidget {
  const _ContactUsPromptSection({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Need Help or Want to Share Something?',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Have a question, issue, or suggestion? Tap the button below and send us a message from the Contact Us page.',
              style: AppTypography.body.copyWith(
                color:
                    isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Go To Contact Us'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        ShimmerLoader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ShimmerBox(width: double.infinity, height: 110, radius: 20),
              const SizedBox(height: 24),
              ShimmerBox(width: 160, height: 20, radius: 8),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                ],
              ),
              const SizedBox(height: 24),
              ShimmerBox(width: 140, height: 20, radius: 8),
              const SizedBox(height: 12),
              const SkeletonCanteenCard(),
              const SizedBox(height: 14),
              const SkeletonCanteenCard(),
            ],
          ),
        ),
      ],
    );
  }
}
