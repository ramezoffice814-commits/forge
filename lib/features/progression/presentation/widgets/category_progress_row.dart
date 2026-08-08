import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../missions/domain/enums/mission_category.dart';
import '../../domain/entities/category_progress.dart';

/// One category's cosmetic "mastery" row — a tier label and a bar toward
/// the next tier, never phrased as a certification (spec section 12).
class CategoryProgressRow extends StatelessWidget {
  const CategoryProgressRow({super.key, required this.progress});

  final CategoryProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final next = progress.nextTierRequirement;
    final ratio = next == null
        ? 1.0
        : (progress.completedCount / next).clamp(0, 1).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.space1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                missionCategoryLabel(progress.category),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                categoryMasteryTierLabel(progress.currentTier),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.accent),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.space1),
          ClipRRect(
            borderRadius: tokens.radius.smRadius,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: tokens.accent,
              backgroundColor: tokens.divider,
            ),
          ),
          if (next != null) ...[
            SizedBox(height: tokens.spacing.space1),
            Text(
              '${progress.completedCount} / $next completed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.text.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
