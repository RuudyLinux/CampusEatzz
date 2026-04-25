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
import '../../data/models/canteen.dart';
import '../../data/models/menu_item.dart';
import '../../state/canteen_provider.dart';
import '../../state/cart_provider.dart';

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
  int? _selectedCanteenId;
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
        setState(() => _selectedCanteenId = canteenId);
        await canteenProvider.loadMenu(canteenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canteenState = context.watch<CanteenProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedId = _selectedCanteenId;
    final menuRows =
        selectedId == null ? const <MenuItem>[] : canteenState.menuFor(selectedId);

    final categories = <String>{'All Categories'};
    for (final item in menuRows) {
      if (item.category.trim().isNotEmpty) categories.add(item.category.trim());
    }

    final visibleRows = _selectedCategory == 'All Categories'
        ? menuRows
        : menuRows
            .where((item) => item.category == _selectedCategory)
            .toList(growable: false);

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
              onRetry: selectedId == null
                  ? null
                  : () => context
                      .read<CanteenProvider>()
                      .loadMenu(selectedId, force: true),
              skeleton: const _MenuSkeleton(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  // Canteen selector + category chips
                  AnimatedReveal(
                    delayMs: 60,
                    child: _FilterCard(
                      isDark: isDark,
                      canteens: canteenState.canteens,
                      selectedCanteenId: selectedId,
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onCanteenChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          _selectedCanteenId = value;
                          _selectedCategory = 'All Categories';
                        });
                        await context.read<CanteenProvider>().loadMenu(value);
                      },
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
    );
  }
}

// ── Filter Card ───────────────────────────────────────────────────────────────

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.isDark,
    required this.canteens,
    required this.selectedCanteenId,
    required this.categories,
    required this.selectedCategory,
    required this.onCanteenChanged,
    required this.onCategoryChanged,
  });

  final bool isDark;
  final List<Canteen> canteens;
  final int? selectedCanteenId;
  final Set<String> categories;
  final String selectedCategory;
  final ValueChanged<int?> onCanteenChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (canteens.isNotEmpty) ...<Widget>[
              DropdownButtonFormField<int>(
                initialValue: selectedCanteenId,
                decoration: const InputDecoration(
                  labelText: 'Select Canteen',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: canteens
                    .map((c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: onCanteenChanged,
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Filter by Category',
              style: AppTypography.label.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
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
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) => onCategoryChanged(category),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
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
            // Image
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
            // Info
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
                                          Text('${item.name} added to cart')),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label:
                            Text(item.isAvailable ? 'Add to Cart' : 'Sold Out'),
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
          ShimmerBox(width: double.infinity, height: 100, radius: 16),
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
