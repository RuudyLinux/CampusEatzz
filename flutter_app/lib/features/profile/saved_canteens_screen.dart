import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/network_food_image.dart';
import '../../state/canteen_provider.dart';
import '../../state/saved_canteens_provider.dart';
import '../menu/menu_screen.dart';

class SavedCanteensScreen extends StatelessWidget {
  const SavedCanteensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = context.watch<SavedCanteensProvider>();
    final canteenProvider = context.watch<CanteenProvider>();

    final savedCanteens = canteenProvider.canteens
        .where((c) => saved.isSaved(c.id))
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Saved Canteens',
            style: AppTypography.heading3.copyWith(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: savedCanteens.isEmpty
          ? const AppEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No Saved Canteens',
              subtitle:
                  'Tap the heart icon on any canteen card to save it here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: savedCanteens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final canteen = savedCanteens[i];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.shadowPink,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MenuScreen(
                          canteenId: canteen.id,
                          canteenName: canteen.name,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Image
                        canteen.imageUrl.isNotEmpty
                            ? NetworkFoodImage(
                                imageUrl: canteen.imageUrl,
                                fallbackAsset: 'assets/images/Restaurants.jpg',
                                width: 90,
                                height: 90,
                                borderRadius: BorderRadius.zero,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 90,
                                height: 90,
                                color: AppColors.surfaceRaised,
                                child: const Icon(Icons.storefront_rounded,
                                    color: AppColors.textMuted, size: 36),
                              ),
                        // Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  canteen.name,
                                  style: AppTypography.label.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                if (canteen.description.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 3),
                                  Text(
                                    canteen.description,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Unsave button
                        IconButton(
                          icon: const Icon(Icons.favorite_rounded,
                              color: AppColors.primary),
                          onPressed: () =>
                              context.read<SavedCanteensProvider>().toggle(canteen.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
