import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/enums/promotion_status.dart';

/// One row of a league leaderboard. Renders only the public-safe fields
/// [LeaderboardEntry] itself carries — there is nothing to accidentally
/// over-render here, since the entry never has anything more sensitive on
/// it (see the entity's own privacy doc comment).
class LeaderboardEntryTile extends StatelessWidget {
  const LeaderboardEntryTile({
    super.key,
    required this.entry,
    this.isCurrentUser = false,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Semantics(
      label:
          'Rank ${entry.rank}, ${entry.displayName}, '
          '${entry.weeklyScore.toStringAsFixed(0)} points'
          '${isCurrentUser ? ', this is you' : ''}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.space3,
          vertical: tokens.spacing.space2,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? tokens.accentRamp.c800.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: tokens.radius.mdRadius,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${entry.rank}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            SizedBox(width: tokens.spacing.space2),
            Expanded(
              child: Text(
                isCurrentUser
                    ? '${entry.displayName} (You)'
                    : entry.displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.space2),
            _ZoneTag(status: entry.promotionStatus),
            SizedBox(width: tokens.spacing.space2),
            Text(
              entry.weeklyScore.toStringAsFixed(0),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneTag extends StatelessWidget {
  const _ZoneTag({required this.status});

  final PromotionStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PromotionStatus.promotionZone => const ForgeTag(
        label: 'Promotion zone',
        variant: ForgeTagVariant.accent,
      ),
      PromotionStatus.demotionZone => const ForgeTag(
        label: 'Demotion zone',
        variant: ForgeTagVariant.outline,
      ),
      PromotionStatus.safeZone => const SizedBox.shrink(),
    };
  }
}
