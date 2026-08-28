import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_progress_ring.dart';
import '../../domain/entities/dashboard_overview.dart';

/// The discipline-progress focal point: a day-count ring plus streak,
/// level, and weekly-completion stats. Every value comes straight from
/// [overview] — no percentage or day-count math happens in this widget.
class DisciplineOverviewCard extends StatelessWidget {
  const DisciplineOverviewCard({super.key, required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final dayFraction = overview.totalChallengeDays == 0
        ? 0.0
        : overview.currentDay / overview.totalChallengeDays;

    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label:
              'Discipline progress: day ${overview.currentDay} of '
              '${overview.totalChallengeDays}',
          value: '${(dayFraction * 100).round()} percent',
          child: ExcludeSemantics(
            child: ForgeProgressRing(
              progress: dayFraction,
              size: 160,
              strokeWidth: 12,
              // The ring is a fixed 160x160 — letting its inner label scale
              // 1:1 with a large system text size breaks that circle's
              // layout well before the rest of the (fully scrollable, fully
              // scalable) page would have any trouble. The information is
              // never lost: it's carried in full by the Semantics label
              // above regardless of this visual cap.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${overview.currentDay}',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      'of ${overview.totalChallengeDays} days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.space4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Stat(label: 'Streak', value: '${overview.currentStreak}d'),
            _Stat(label: 'Level', value: '${overview.currentLevel}'),
            _Stat(
              label: 'This week',
              value: '${overview.weeklyCompletionPercent}%',
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.space4),
        Semantics(
          label: 'Progress to level ${overview.currentLevel + 1}',
          value: '${(overview.levelProgress * 100).round()} percent',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: overview.levelProgress.clamp(0, 1),
                minHeight: 6,
                backgroundColor: tokens.neutralRamp.c800,
                valueColor: AlwaysStoppedAnimation(tokens.accent),
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.space1),
        Text(
          '${overview.xpToNextLevel} XP to level ${overview.currentLevel + 1}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.text.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
