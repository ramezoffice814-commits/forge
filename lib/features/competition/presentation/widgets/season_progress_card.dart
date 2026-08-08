import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../domain/usecases/get_season_progress_usecase.dart';

/// Every value here is explicitly marked provisional (spec section 29) —
/// nothing in local/mock mode is a confirmed season result.
class SeasonProgressCard extends StatelessWidget {
  const SeasonProgressCard({super.key, required this.snapshot});

  final SeasonProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final season = snapshot.season;
    final seasonScore = snapshot.seasonScore;

    return ForgeCard(
      elevation: ForgeCardElevation.md,
      children: [
        Text(season.name, style: Theme.of(context).textTheme.titleMedium),
        Text(
          'Week ${snapshot.currentWeek.weekNumber} of ${season.weekCount}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: tokens.spacing.space2),
        ClipRRect(
          borderRadius: tokens.radius.mdRadius,
          child: LinearProgressIndicator(
            value: snapshot.weekProgressFraction,
            minHeight: 6,
            backgroundColor: tokens.neutralRamp.c800,
            color: tokens.accent,
          ),
        ),
        SizedBox(height: tokens.spacing.space2),
        Text(
          '${seasonScore.totalSeasonScore.toStringAsFixed(0)} season points '
          '(preview)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          seasonScore.scoringRule,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.7),
          ),
        ),
        if (seasonScore.droppedWeeks.isNotEmpty)
          Text(
            'Dropped weeks: ${seasonScore.droppedWeeks.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}
