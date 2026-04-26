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
import '../../core/widgets/network_food_image.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/canteen.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/recommendation_item.dart';
import '../../state/auth_provider.dart';
import '../../state/canteen_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/recommendation_provider.dart';
import '../chat/chatbot_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final canteenProvider = context.read<CanteenProvider>();
      final recProvider = context.read<RecommendationProvider>();
      final userId = context.read<AuthProvider>().session?.id ?? 0;
      await canteenProvider.loadCanteens();
      if (!mounted) return;
      for (final canteen in canteenProvider.canteens) {
        await canteenProvider.loadMenu(canteen.id);
        if (!mounted) return;
      }
      await recProvider.loadAll(userId: userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canteenState = context.watch<CanteenProvider>();
    final recState = context.watch<RecommendationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greeting = _greeting();

    return Scaffold(
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.home),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChatbot,
        backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text('AI Assistant'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                onRefresh: () async {
                  final canteenProvider = context.read<CanteenProvider>();
                  final recProvider = context.read<RecommendationProvider>();
                  final userId = context.read<AuthProvider>().session?.id ?? 0;
                  await canteenProvider.loadCanteens();
                  if (!mounted) return;
                  await recProvider.loadAll(userId: userId);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: <Widget>[
                    AnimatedReveal(
                        delayMs: 60, child: _HeroBanner(isDark: isDark)),
                    const SizedBox(height: 24),
                    AnimatedReveal(
                        delayMs: 130, child: _FeatureRow(isDark: isDark)),
                    const SizedBox(height: 24),
                    // AI Recommendations — "Recommended For You"
                    if (recState.personal != null &&
                        recState.personal!.items.isNotEmpty)
                      AnimatedReveal(
                        delayMs: 170,
                        child: _RecommendationSection(
                          section: recState.personal!,
                          isDark: isDark,
                          icon: Icons.auto_awesome_rounded,
                          iconColor: AppColors.accent,
                        ),
                      ),
                    if (recState.personal != null &&
                        recState.personal!.items.isNotEmpty)
                      const SizedBox(height: 24),
                    // AI Recommendations — Trending Now
                    if (recState.trending != null &&
                        recState.trending!.items.isNotEmpty)
                      AnimatedReveal(
                        delayMs: 200,
                        child: _RecommendationSection(
                          section: recState.trending!,
                          isDark: isDark,
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppColors.warning,
                        ),
                      ),
                    if (recState.trending != null &&
                        recState.trending!.items.isNotEmpty)
                      const SizedBox(height: 24),
                    // Budget Meals
                    if (recState.budgetMeals != null &&
                        recState.budgetMeals!.items.isNotEmpty)
                      AnimatedReveal(
                        delayMs: 230,
                        child: _RecommendationSection(
                          section: recState.budgetMeals!,
                          isDark: isDark,
                          icon: Icons.savings_rounded,
                          iconColor: AppColors.success,
                        ),
                      ),
                    if (recState.budgetMeals != null &&
                        recState.budgetMeals!.items.isNotEmpty)
                      const SizedBox(height: 24),
                    AnimatedReveal(
                      delayMs: 260,
                      child: _CanteenSection(
                        canteens: canteenState.canteens,
                        isDark: isDark,
                        onTap: _openMenu,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedReveal(
                        delayMs: 310,
                        child: _TrendingSection(
                          isDark: isDark,
                          items: canteenState.allItems.take(6).toList(),
                        )),
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delayMs: 360,
                      child: _AiChatBannerSection(
                        isDark: isDark,
                        onTap: _openChatbot,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedReveal(
                      delayMs: 400,
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

  void _openChatbot() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatbotScreen()),
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
  const _TrendingSection({required this.isDark, required this.items});

  final bool isDark;
  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Trending Dishes',
          style: AppTypography.heading3.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final item = items[index];
              return SizedBox(
                width: 160,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      NetworkFoodImage(
                        imageUrl: item.imageUrl,
                        fallbackAsset: 'assets/images/Restaurants.jpg',
                        width: double.infinity,
                        height: 105,
                        borderRadius: BorderRadius.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name,
                              style: AppTypography.label.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatInr(item.price),
                              style: AppTypography.priceSm.copyWith(
                                color: isDark
                                    ? AppColors.primaryOnDark
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: item.isAvailable
                                    ? () async {
                                        await context
                                            .read<CartProvider>()
                                            .addMenuItem(item);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              '${item.name} added to cart'),
                                          duration:
                                              const Duration(seconds: 1),
                                        ));
                                      }
                                    : null,
                                icon: const Icon(Icons.add_rounded, size: 13),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  minimumSize: const Size(0, 30),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
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

// ── AI Recommendation Section ─────────────────────────────────────────────────

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.section,
    required this.isDark,
    required this.icon,
    required this.iconColor,
  });

  final RecommendationSection section;
  final bool isDark;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    section.title,
                    style: AppTypography.heading3.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    section.subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = section.items[index];
              return SizedBox(
                width: 160,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      NetworkFoodImage(
                        imageUrl: item.imageUrl,
                        fallbackAsset: 'assets/images/Restaurants.jpg',
                        width: double.infinity,
                        height: 90,
                        borderRadius: BorderRadius.zero,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
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
                                    formatInr(item.price),
                                    style: AppTypography.priceSm.copyWith(
                                      color: isDark
                                          ? AppColors.primaryOnDark
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.reason,
                                    style: AppTypography.caption.copyWith(
                                      color: iconColor,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: item.isAvailable
                                      ? () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                'Browse ${item.canteenName} to add ${item.name}'),
                                            duration:
                                                const Duration(seconds: 2),
                                          ));
                                        }
                                      : null,
                                  icon: const Icon(Icons.storefront_rounded,
                                      size: 12),
                                  label: Text(
                                    item.canteenName.split(' ').first,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    minimumSize: const Size(0, 28),
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

// ── AI Chat Banner ──────────────────────────────────────────────────────────���─

class _AiChatBannerSection extends StatelessWidget {
  const _AiChatBannerSection({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[
                      AppColors.accent.withValues(alpha: 0.3),
                      AppColors.primary.withValues(alpha: 0.2),
                    ]
                  : <Color>[
                      AppColors.accent.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.06),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.darkHeaderGradient
                      : AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ask CampusEatzz AI',
                      style: AppTypography.heading3.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '"Suggest food under ₹100" or "What\'s popular today?"',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: isDark ? AppColors.primaryOnDark : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contact Us Section ────────────────────────────────────────────────────────

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
