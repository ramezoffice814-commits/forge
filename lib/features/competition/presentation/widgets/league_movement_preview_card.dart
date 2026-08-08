import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../domain/entities/league_movement.dart';
import '../../domain/enums/promotion_status.dart';

/// Always worded as a preview — "Currently in promotion zone," never "You
/// will be promoted" (spec section 30). Nothing here is a guarantee; local
/// mode has no authority to finalize a league movement.
class LeagueMovementPreviewCard extends StatelessWidget {
  const LeagueMovementPreviewCard({super.key, required this.preview});

  final LeagueMovementPreview preview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final (label, variant, description) = switch (preview.zone) {
      PromotionStatus.promotionZone => (
        'Currently in promotion zone',
        ForgeTagVariant.accent,
        'Stay here through the end of the week to be considered for '
            'promotion.',
      ),
      PromotionStatus.demotionZone => (
        'Currently in demotion zone',
        ForgeTagVariant.outline,
        'There is still time this week to move out of this zone.',
      ),
      PromotionStatus.safeZone => (
        'Safe zone',
        ForgeTagVariant.neutral,
        'You are outside both the promotion and demotion zones for now.',
      ),
    };

    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.space2,
          runSpacing: tokens.spacing.space1,
          children: [
            Text(
              'Rank ${preview.currentRank}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ForgeTag(label: label, variant: variant),
          ],
        ),
        SizedBox(height: tokens.spacing.space1),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.8),
          ),
        ),
        if (preview.pointsToNextRank > 0) ...[
          SizedBox(height: tokens.spacing.space1),
          Text(
            '${preview.pointsToNextRank.toStringAsFixed(0)} points to the '
            'next rank',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
