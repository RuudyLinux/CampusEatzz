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
    final cart = context.watch<CartProvider>();
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

    // Show checkout bar only when cart has items from THIS canteen
    final showCheckoutBar = cart.items.isNotEmpty &&
        widget.canteenId != null &&
        cart.activeCanteenId == widget.canteenId;

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
                    16, 16, 16, showCheckoutBar ? 90 : 24),
                children: <Widget>[
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
          if (showCheckoutBar)
            _CheckoutBar(
              itemCount: cart.totalItems,
              total: cart.total,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

// ── Checkout Bar ──────────────────────────────────────────────────────────────

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.itemCount,
    required this.total,
    required this.isDark,
  });

  final int itemCount;
  final double total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.primaryOnDark : AppColors.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: AppTypography.labelSm
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'View Cart',
                  style: AppTypography.label
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  formatInr(total),
                  style: AppTypography.label
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
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
                    foodName: item.name,
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
                                final cart = context.read<CartProvider>();
                                if (cart.hasCanteenConflict(item)) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Start new cart?'),
                                      content: const Text(
                                        'Your cart has items from a different canteen. Adding this item will clear your current cart.',
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Clear & Add'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  if (!context.mounted) return;
                                  await context
                                      .read<CartProvider>()
                                      .clearAndAddMenuItem(item);
                                } else {
                                  await cart.addMenuItem(item);
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} added to cart'),
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
