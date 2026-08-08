import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../domain/entities/league_preview.dart';

/// Display-only — rank/promotion math is computed server-side and handed
/// down through [league]; this widget never calculates anything.
class LeaguePreviewCard extends StatelessWidget {
  const LeaguePreviewCard({
    super.key,
    required this.league,
    required this.onOpenRank,
  });

  final LeaguePreview league;
  final VoidCallback onOpenRank;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final inPromotionZone = league.promotionZoneDistance <= 0;

    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      children: [
        Text(league.leagueName, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.spacing.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              label: 'Current rank ${league.currentPosition}',
              child: ExcludeSemantics(
                child: Text(
                  '#${league.currentPosition}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            Text(
              inPromotionZone
                  ? 'In promotion zone'
                  : '${league.promotionZoneDistance} to promotion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.text.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.space1),
        Text(
          league.weekEndingLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        SizedBox(height: tokens.spacing.space3),
        ForgeButton(
          label: 'View Rank',
          variant: ForgeButtonVariant.secondary,
          onPressed: onOpenRank,
        ),
      ],
    );
  }
}
