import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../providers/competition_controller.dart';
import '../providers/competition_state.dart';

/// Profile's competition summary (spec section 36): current league and
/// this season's standing. "Highest league achieved" and "best season
/// finish" are deliberately not fabricated here — this local/mock phase
/// has no persisted season history for the real user yet, only for the
/// seeded Hall of Fame population, so showing either would mean inventing
/// data. They appear honestly once a season has actually completed.
class ProfileCompetitionSummary extends ConsumerWidget {
  const ProfileCompetitionSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(competitionControllerProvider);
    if (state is! CompetitionReady) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final current = state.current;
    final seasonScore = state.seasonProgress.seasonScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Competition', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space1),
        Text(
          'Current league: ${current.league.name}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${state.seasonProgress.season.name}: '
          '${seasonScore.totalSeasonScore.toStringAsFixed(0)} pts (preview)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
