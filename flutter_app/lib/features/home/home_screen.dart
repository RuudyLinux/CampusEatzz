import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/food_image_resolver.dart';
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
import '../../state/saved_canteens_provider.dart';
import '../chat/chatbot_screen.dart';
import '../contact/contact_us_screen.dart';
import '../menu/menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _canteenSectionKey = GlobalKey();
  bool _filterVegOnly = false;
  bool _filterOpenOnly = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCanteens() {
    final ctx = _canteenSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openSearch(BuildContext context) {
    final canteenProvider = context.read<CanteenProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        canteens: canteenProvider.canteens,
        allItems: canteenProvider.allItems,
        onOpenMenu: (canteen) {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                MenuScreen(canteenId: canteen.id, canteenName: canteen.name),
          ));
        },
      ),
    );
  }

  Future<void> _openFilter(BuildContext context) async {
    final result = await showModalBottomSheet<({bool vegOnly, bool openOnly})?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _filterVegOnly = result.vegOnly;
        _filterOpenOnly = result.openOnly;
      });
    }
  }

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
    final session = context.watch<AuthProvider>().session;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greeting = _greeting(session?.firstName.trim().isNotEmpty == true
        ? session!.firstName.trim()
        : session?.name.split(' ').first.trim() ?? '');

    var filteredCanteens = canteenState.canteens;
    if (_filterOpenOnly) {
      filteredCanteens = filteredCanteens
          .where((c) => c.status.toLowerCase() == 'open')
          .toList(growable: false);
    }
    if (_filterVegOnly) {
      filteredCanteens = filteredCanteens
          .where((c) =>
              canteenState.menuFor(c.id).any((item) => item.isVegetarian))
          .toList(growable: false);
    }

    return Scaffold(
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.home),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbot,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.smart_toy_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: 'CampusEatzz',
            subtitle: greeting,
            trailing: const NotificationBellButton(),
            minimal: true,
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
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: <Widget>[
                    AnimatedReveal(
                      delayMs: 30,
                      child: _SearchBar(
                        isDark: isDark,
                        onTap: () => _openSearch(context),
                        onFilter: () => _openFilter(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedReveal(
                      delayMs: 60,
                      child: _HeroBanner(
                        isDark: isDark,
                        onBrowse: _scrollToCanteens,
                      ),
                    ),
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
                        key: _canteenSectionKey,
                        canteens: filteredCanteens,
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

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final base = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return name.isEmpty ? base : '$base, $name';
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.isDark,
    required this.onTap,
    required this.onFilter,
  });
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.shadowPink,
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 18),
            Icon(
              Icons.search_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search canteens, dishes…',
                style: AppTypography.body.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
            ),
            GestureDetector(
              onTap: onFilter,
              child: Container(
                margin: const EdgeInsets.all(6),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(44),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.isDark, required this.onBrowse});

  final bool isDark;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Label chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'CAMPUS CANTEENS',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Big headline
          RichText(
            text: TextSpan(
              style: AppTypography.heading1.copyWith(color: textColor),
              children: <InlineSpan>[
                const TextSpan(text: 'Taste the '),
                TextSpan(
                  text: 'Difference',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: '\nwith Campus Food'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Order your favorite meals — fast, easy, and cashless.',
            style: AppTypography.bodySm.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 18),
          // CTA pill button — taps scroll to canteen section
          GestureDetector(
            onTap: onBrowse,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(50),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Text('Browse Canteens',
                      style: AppTypography.label.copyWith(color: Colors.white)),
                  const SizedBox(width: 20),
                ],
              ),
            ),
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
    super.key,
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
          const AppEmptyState(
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
    final saved = context.watch<SavedCanteensProvider>();
    final isSaved = saved.isSaved(canteen.id);
    final isOpen = canteen.status.toLowerCase() == 'open';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowPink,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(canteen),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Image with overlays ─────────────────────────────────
            Stack(
              children: <Widget>[
                canteen.imageUrl.isNotEmpty
                    ? NetworkFoodImage(
                        imageUrl: canteen.imageUrl,
                        fallbackAsset: 'assets/images/Restaurants.jpg',
                        height: 190,
                        borderRadius: BorderRadius.zero,
                      )
                    : Container(
                        width: double.infinity,
                        height: 190,
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.surfaceRaised,
                        child: Icon(Icons.storefront_rounded,
                            size: 60,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted),
                      ),
                // Status pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.success : AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.circle, size: 6, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isOpen ? 'Open' : 'Closed',
                          style: AppTypography.labelSm
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Heart / save button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => saved.toggle(canteen.id),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isSaved ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Info ────────────────────────────────────────────────
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
                      Icon(Icons.restaurant_menu_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary),
                      const SizedBox(width: 5),
                      Text('View Menu',
                          style: AppTypography.label.copyWith(
                              color: isDark
                                  ? AppColors.primaryOnDark
                                  : AppColors.primary)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary),
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
                        foodName: item.name,
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
          height: 222,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = section.items[index];
              return _RecommendationCard(
                item: item,
                isDark: isDark,
                iconColor: iconColor,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Recommendation Card ───────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.item,
    required this.isDark,
    required this.iconColor,
  });

  final RecommendationItem item;
  final bool isDark;
  final Color iconColor;

  static const List<List<Color>> _gradients = <List<Color>>[
    <Color>[Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    <Color>[Color(0xFF4ECDC4), Color(0xFF44A08D)],
    <Color>[Color(0xFF6C63FF), Color(0xFFA78BFA)],
    <Color>[Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)],
    <Color>[Color(0xFFF093FB), Color(0xFFF5576C)],
    <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)],
    <Color>[Color(0xFFFA709A), Color(0xFFFEE140)],
  ];

  static const List<IconData> _foodIcons = <IconData>[
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.lunch_dining_rounded,
    Icons.bakery_dining_rounded,
    Icons.ramen_dining_rounded,
    Icons.set_meal_rounded,
    Icons.local_pizza_rounded,
    Icons.emoji_food_beverage_rounded,
  ];

  List<Color> _gradientForItem() {
    final hash = item.name.codeUnits.fold(0, (int a, int b) => a + b);
    return _gradients[hash % _gradients.length];
  }

  IconData _iconForItem() {
    final hash = item.name.codeUnits.fold(0, (int a, int b) => a + b);
    return _foodIcons[(hash + 3) % _foodIcons.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.trim().isNotEmpty;
    final grad = _gradientForItem();
    final mappedFoodAsset = FoodImageResolver.assetForFoodName(item.name);
    final hasMappedMenuUpload =
        FoodImageResolver.uploadUrlForFoodName(item.name) != null;
    final canRenderFoodImage = hasImage || mappedFoodAsset != null || hasMappedMenuUpload;

    return SizedBox(
      width: 160,
      height: 222,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            // ── Image / placeholder ─────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 92,
              child: canRenderFoodImage
                  ? NetworkFoodImage(
                      imageUrl: item.imageUrl,
                      fallbackAsset:
                          mappedFoodAsset ?? FoodImageResolver.defaultFoodAsset,
                      foodName: item.name,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 92,
                      borderRadius: BorderRadius.zero,
                    )
                  : _Placeholder(grad: grad, icon: _iconForItem()),
            ),
            // ── Text content ────────────────────────────────────
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
                            fontSize: 12,
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
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.reason,
                          style: TextStyle(
                            fontSize: 9,
                            color: iconColor,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: item.isAvailable
                            ? () async {
                                await context
                                    .read<CartProvider>()
                                    .addMenuItem(_toMenuItem());
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} added to cart'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 13),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 28),
                          maximumSize: const Size(double.infinity, 28),
                          textStyle: const TextStyle(fontSize: 10),
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
  }

  MenuItem _toMenuItem() {
    return MenuItem(
      id: item.id,
      name: item.name,
      description: item.reason,
      price: item.price,
      category: item.category,
      imageUrl: item.imageUrl,
      isAvailable: item.isAvailable,
      isVegetarian: false,
      canteenId: item.canteenId,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.grad, required this.icon});
  final List<Color> grad;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 36),
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

// ── Search Sheet ─────────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.canteens,
    required this.allItems,
    required this.onOpenMenu,
  });
  final List<Canteen> canteens;
  final List<MenuItem> allItems;
  final void Function(Canteen) onOpenMenu;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _query.toLowerCase().trim();

    final matchedCanteens = q.isEmpty
        ? widget.canteens
        : widget.canteens
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q))
            .toList();

    final matchedItems = q.isEmpty
        ? <MenuItem>[]
        : widget.allItems
            .where((i) =>
                i.name.toLowerCase().contains(q) ||
                i.category.toLowerCase().contains(q))
            .take(10)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: <Widget>[
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: AppColors.shadowPink,
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (mounted) setState(() => _query = v);
                      },
                    );
                  },
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search canteens, dishes…',
                    hintStyle: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                  ),
                ),
              ),
            ),
            // Results
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: <Widget>[
                  if (matchedCanteens.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text('Canteens',
                          style: AppTypography.labelSm.copyWith(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                            letterSpacing: 0.8,
                          )),
                    ),
                    ...matchedCanteens.map((c) => ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text(c.name,
                              style: AppTypography.label.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              )),
                          subtitle: Text(
                            c.description.isEmpty
                                ? 'Campus canteen'
                                : c.description,
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpenMenu(c);
                          },
                        )),
                  ],
                  if (matchedItems.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 12),
                      child: Text('Dishes',
                          style: AppTypography.labelSm.copyWith(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                            letterSpacing: 0.8,
                          )),
                    ),
                    ...matchedItems.map((item) => ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lunch_dining_rounded,
                                color: AppColors.accent, size: 20),
                          ),
                          title: Text(item.name,
                              style: AppTypography.label.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              )),
                          subtitle: Text(item.category,
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                              )),
                          trailing: Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: AppTypography.priceSm.copyWith(
                              color: isDark
                                  ? AppColors.primaryOnDark
                                  : AppColors.primary,
                            ),
                          ),
                        )),
                  ],
                  if (matchedCanteens.isEmpty && matchedItems.isEmpty && q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('No results for "$_query"',
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted,
                            )),
                      ),
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

// ── Filter Sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  bool _vegOnly = false;
  bool _openOnly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Filters',
              style: AppTypography.heading3.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              )),
          const SizedBox(height: 20),
          // Vegetarian toggle
          _FilterRow(
            isDark: isDark,
            icon: Icons.eco_rounded,
            iconColor: AppColors.success,
            label: 'Vegetarian only',
            subtitle: 'Show only veg items',
            value: _vegOnly,
            onChanged: (v) => setState(() => _vegOnly = v),
          ),
          const SizedBox(height: 12),
          // Open now toggle
          _FilterRow(
            isDark: isDark,
            icon: Icons.storefront_rounded,
            iconColor: AppColors.primary,
            label: 'Open now',
            subtitle: 'Show only open canteens',
            value: _openOnly,
            onChanged: (v) => setState(() => _openOnly = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .pop<({bool vegOnly, bool openOnly})>(
                    (vegOnly: _vegOnly, openOnly: _openOnly),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 50),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: AppColors.shadowPink,
              blurRadius: 10,
              offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label,
                    style: AppTypography.label.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    )),
                Text(subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            trackColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.30);
              }
              return null;
            }),
          ),
        ],
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
      children: const <Widget>[
        ShimmerLoader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ShimmerBox(width: double.infinity, height: 110, radius: 20),
              SizedBox(height: 24),
              ShimmerBox(width: 160, height: 20, radius: 8),
              SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                  SizedBox(width: 10),
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                  SizedBox(width: 10),
                  Expanded(
                      child: ShimmerBox(
                          width: double.infinity, height: 100, radius: 16)),
                ],
              ),
              SizedBox(height: 24),
              ShimmerBox(width: 140, height: 20, radius: 8),
              SizedBox(height: 12),
              SkeletonCanteenCard(),
              SizedBox(height: 14),
              SkeletonCanteenCard(),
            ],
          ),
        ),
      ],
    );
  }
}
