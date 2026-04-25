import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_async_view.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/gradient_header.dart';
import '../../core/widgets/network_food_image.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/menu_item.dart';
import '../../state/canteen_provider.dart';
import '../../state/cart_provider.dart';
import '../cart/cart_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    this.canteenId,
    this.canteenName,
  });

  final int? canteenId;
  final String? canteenName;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _selectedCategory = 'All Categories';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final canteenProvider = context.read<CanteenProvider>();
      if (canteenProvider.canteens.isEmpty) {
        await canteenProvider.loadCanteens();
        if (!mounted) return;
      }

      final canteenId = widget.canteenId ??
          (canteenProvider.canteens.isNotEmpty
              ? canteenProvider.canteens.first.id
              : null);
      if (canteenId != null) {
        await canteenProvider.loadMenu(canteenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canteenState = context.watch<CanteenProvider>();
    final cartState = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final menuRows = widget.canteenId == null
        ? const <MenuItem>[]
        : canteenState.menuFor(widget.canteenId!);

    final categories = <String>{'All Categories'};
    for (final item in menuRows) {
      if (item.category.trim().isNotEmpty) categories.add(item.category.trim());
    }

    final visibleRows = _selectedCategory == 'All Categories'
        ? menuRows
        : menuRows
            .where((item) => item.category == _selectedCategory)
            .toList(growable: false);

    final cartCount = cartState.totalItems;

    return Scaffold(
      body: Column(
        children: <Widget>[
          GradientHeader(
            title: widget.canteenName ?? 'Menu',
            subtitle: 'Fresh, delicious dishes daily',
            showLogo: false,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: AppAsyncView(
              isLoading: canteenState.loadingMenu,
              error: canteenState.error,
              onRetry: widget.canteenId == null
                  ? null
                  : () => context
                      .read<CanteenProvider>()
                      .loadMenu(widget.canteenId!, force: true),
              skeleton: const _MenuSkeleton(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, cartCount > 0 ? 90 : 24),
                children: <Widget>[
                  // Category chips
                  AnimatedReveal(
                    delayMs: 60,
                    child: _CategoryBar(
                      isDark: isDark,
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onCategoryChanged: (cat) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visibleRows.isEmpty)
                    AnimatedReveal(
                      delayMs: 120,
                      child: AppEmptyState(
                        icon: Icons.no_food_outlined,
                        title: 'Nothing Here',
                        subtitle:
                            'No items in this category. Try another filter.',
                        compact: true,
                      ),
                    )
                  else
                    ...visibleRows.asMap().entries.map((entry) {
                      return AnimatedReveal(
                        delayMs: 120 + (entry.key * 40),
                        child: _MenuCard(item: entry.value, isDark: isDark),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: cartCount > 0
          ? _CartFab(count: cartCount, isDark: isDark)
          : null,
    );
  }
}

// ── Cart FAB ──────────────────────────────────────────────────────────────────

class _CartFab extends StatelessWidget {
  const _CartFab({required this.count, required this.isDark});

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CartScreen()),
      ),
      backgroundColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: isDark ? AppColors.primaryOnDark : AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      label: Text(
        'View Cart',
        style: AppTypography.label.copyWith(color: Colors.white),
      ),
    );
  }
}

// ── Category Bar ──────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.isDark,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final bool isDark;
  final Set<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isActive = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isActive,
              selectedColor:
                  isDark ? AppColors.primaryOnDark : AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isActive
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (_) => onCategoryChanged(category),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Menu Card ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item, required this.isDark});

  final MenuItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.imageUrl.isNotEmpty)
              Stack(
                children: <Widget>[
                  NetworkFoodImage(
                    imageUrl: item.imageUrl,
                    fallbackAsset: 'assets/images/Restaurants.jpg',
                    height: 170,
                    borderRadius: BorderRadius.zero,
                  ),
                  if (item.isVegetarian)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.eco_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Veg',
                              style: AppTypography.labelSm
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!item.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Unavailable',
                            style: AppTypography.label
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: AppTypography.heading3.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        formatInr(item.price),
                        style: AppTypography.price.copyWith(
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: item.isAvailable
                            ? () async {
                                await context
                                    .read<CartProvider>()
                                    .addMenuItem(item);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('${item.name} added to cart'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                            item.isAvailable ? 'Add to Cart' : 'Sold Out'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 38),
                        ),
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

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          ShimmerBox(width: double.infinity, height: 50, radius: 16),
          const SizedBox(height: 16),
          const SkeletonMenuCard(),
          const SizedBox(height: 14),
          const SkeletonMenuCard(),
          const SizedBox(height: 14),
          const SkeletonMenuCard(),
        ],
      ),
    );
  }
}
