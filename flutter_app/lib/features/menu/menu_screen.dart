import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/formatters.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/network_food_image.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../data/models/canteen.dart';
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
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
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
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canteenState = context.watch<CanteenProvider>();
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canteen = widget.canteenId == null
        ? null
        : canteenState.canteens.where((c) => c.id == widget.canteenId).firstOrNull;

    final menuRows = widget.canteenId == null
        ? const <MenuItem>[]
        : canteenState.menuFor(widget.canteenId!);

    final categories = <String>['All'];
    for (final item in menuRows) {
      if (item.category.trim().isNotEmpty &&
          !categories.contains(item.category.trim())) {
        categories.add(item.category.trim());
      }
    }

    final visibleRows = _selectedCategory == 'All'
        ? menuRows
        : menuRows
            .where((item) => item.category == _selectedCategory)
            .toList(growable: false);

    final showCheckoutBar = cart.items.isNotEmpty &&
        widget.canteenId != null &&
        cart.activeCanteenId == widget.canteenId;
    final isMaintenance = canteen?.isUnderMaintenance ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              // ── Hero app bar ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                floating: false,
                backgroundColor:
                    isDark ? AppColors.darkSurface : AppColors.primary,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _CanteenHero(
                    canteen: canteen,
                    canteenName:
                        widget.canteenName ?? canteen?.name ?? 'Menu',
                    isDark: isDark,
                  ),
                ),
                // Collapsed state bar
                title: Text(
                  widget.canteenName ?? 'Menu',
                  style: AppTypography.heading3
                      .copyWith(color: Colors.white, fontSize: 16),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                    light: false,
                  ),
                ),
              ),

              // ── Loading / error / content ─────────────────────────────
              if (canteenState.loadingMenu && menuRows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MenuSkeleton(),
                )
              else if (canteenState.error != null && menuRows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load menu',
                      subtitle: canteenState.error ?? 'Try again',
                      actionLabel: 'Retry',
                      onAction: widget.canteenId == null
                          ? null
                          : () => context
                              .read<CanteenProvider>()
                              .loadMenu(widget.canteenId!, force: true),
                    ),
                  ),
                )
              else ...<Widget>[
                // ── Maintenance banner ────────────────────────────────
                if (isMaintenance)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.construction_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This canteen is currently under maintenance. Ordering is temporarily unavailable.',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Category chips (sticky via SliverPersistentHeader)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryHeaderDelegate(
                    categories: categories,
                    selected: _selectedCategory,
                    isDark: isDark,
                    onChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),
                ),
                // Menu items
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, showCheckoutBar ? 96 : 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (visibleRows.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: AppEmptyState(
                              icon: Icons.no_food_outlined,
                              title: 'Nothing here',
                              subtitle: 'Try a different category.',
                              compact: true,
                            ),
                          );
                        }
                        final item = visibleRows[index];
                        return AnimatedReveal(
                          delayMs: 60 + index * 30,
                          child: _MenuCard(
                            item: item,
                            isDark: isDark,
                            isMaintenance: isMaintenance,
                          ),
                        );
                      },
                      childCount:
                          visibleRows.isEmpty ? 1 : visibleRows.length,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Checkout bar ──────────────────────────────────────────────
          if (showCheckoutBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _CheckoutBar(
                itemCount: cart.totalItems,
                total: cart.total,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Canteen Hero ──────────────────────────────────────────────────────────────

class _CanteenHero extends StatelessWidget {
  const _CanteenHero({
    required this.canteenName,
    required this.isDark,
    this.canteen,
  });

  final Canteen? canteen;
  final String canteenName;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Image
        canteen != null && canteen!.imageUrl.isNotEmpty
            ? NetworkFoodImage(
                imageUrl: canteen!.imageUrl,
                fallbackAsset: 'assets/images/Restaurants.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              )
            : ColoredBox(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.primary.withValues(alpha: 0.85),
                child: const Center(
                  child: Icon(Icons.storefront_rounded,
                      size: 80, color: Colors.white38),
                ),
              ),

        // Gradient overlay bottom → transparent
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.75),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Bottom overlay — canteen info
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                canteenName,
                style: AppTypography.display.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (canteen != null && canteen!.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    canteen!.description,
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 10),
              // Status chip — Maintenance (yellow) / Open (green) / Closed (red)
              Row(
                children: <Widget>[
                  _StatChip(
                    icon: (canteen?.isUnderMaintenance ?? false)
                        ? Icons.construction_rounded
                        : Icons.circle,
                    label: (canteen?.isUnderMaintenance ?? false)
                        ? 'Maintenance'
                        : (canteen?.isOpen ?? false)
                            ? 'Open'
                            : 'Closed',
                    iconColor: (canteen?.isUnderMaintenance ?? false)
                        ? const Color(0xFFD97706)
                        : (canteen?.isOpen ?? false)
                            ? const Color(0xFF4CAF50)
                            : AppColors.danger,
                    iconSize: (canteen?.isUnderMaintenance ?? false) ? 10 : 8,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small circle overlay button (on hero image) ───────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.light = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool light; // true = glass, false = opaque dark

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Stat chip on hero image ───────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.iconSize = 14,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


// ── Category header (sticky) ──────────────────────────────────────────────────

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({
    required this.categories,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  final List<String> categories;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  bool shouldRebuild(_CategoryHeaderDelegate old) =>
      old.selected != selected ||
      old.categories.length != categories.length ||
      old.isDark != isDark;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 56,
      color: isDark ? AppColors.darkBg : AppColors.bg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(50),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                cat,
                style: AppTypography.labelSm.copyWith(
                  color: active
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Menu Card ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.isDark,
    this.isMaintenance = false,
  });

  final MenuItem item;
  final bool isDark;
  final bool isMaintenance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.shadowPink,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image
            if (item.imageUrl.isNotEmpty)
              Stack(
                children: <Widget>[
                  NetworkFoodImage(
                    imageUrl: item.imageUrl,
                    fallbackAsset: 'assets/images/Restaurants.jpg',
                    foodName: item.name,
                    height: 160,
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
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.eco_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('Veg',
                                style: AppTypography.labelSm
                                    .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  if (!item.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.50),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text('Sold Out',
                              style: AppTypography.label
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            // Info row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Veg/non-veg dot
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: item.isVegetarian
                              ? AppColors.success
                              : AppColors.danger,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.isVegetarian
                                ? AppColors.success
                                : AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          style: AppTypography.label.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (item.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            item.description,
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Text(
                              formatInr(item.price),
                              style: AppTypography.price.copyWith(
                                color: isDark
                                    ? AppColors.primaryOnDark
                                    : AppColors.primary,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            _AddButton(
                              item: item,
                              isMaintenance: isMaintenance,
                            ),
                          ],
                        ),
                      ],
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

// ── Add to Cart button — always pink ─────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.item,
    this.isMaintenance = false,
  });

  final MenuItem item;
  final bool isMaintenance;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isMaintenance || !item.isAvailable
          ? null
          : () async {
              final cart = context.read<CartProvider>();
              final messenger = ScaffoldMessenger.of(context);
              if (cart.hasCanteenConflict(item)) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Start new cart?'),
                    content: const Text(
                      'Your cart has items from a different canteen. Adding this clears your current cart.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear & Add'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                if (!context.mounted) return;
                await context.read<CartProvider>().clearAndAddMenuItem(item);
              } else {
                await cart.addMenuItem(item);
              }
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text('${item.name} added'),
                duration: const Duration(seconds: 1),
              ));
            },
      icon: const Icon(Icons.add_rounded, size: 16),
      label: Text(
        isMaintenance
            ? 'Unavailable'
            : item.isAvailable
                ? 'Add'
                : 'Sold Out',
      ),
      style: ElevatedButton.styleFrom(
        // Keep a solid brand accent so icon/text stay readable in dark mode.
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            AppColors.primary.withValues(alpha: 0.30),
        disabledForegroundColor: Colors.white60,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 38),
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: AppTypography.labelSm,
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
    return SafeArea(
      top: false,
      child: Container(
        color: isDark
            ? AppColors.darkBg.withValues(alpha: 0.95)
            : AppColors.bg.withValues(alpha: 0.95),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(50),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      '$itemCount',
                      style: AppTypography.labelSm.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View Cart',
                      style: AppTypography.label.copyWith(color: Colors.white),
                    ),
                  ),
                  Text(
                    formatInr(total),
                    style: AppTypography.label.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
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
        children: const <Widget>[
          ShimmerBox(width: double.infinity, height: 50, radius: 50),
          SizedBox(height: 16),
          SkeletonMenuCard(),
          SizedBox(height: 14),
          SkeletonMenuCard(),
          SizedBox(height: 14),
          SkeletonMenuCard(),
        ],
      ),
    );
  }
}
