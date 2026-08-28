import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../domain/entities/weekly_snapshot.dart';

class WeeklySnapshotCard extends StatelessWidget {
  const WeeklySnapshotCard({super.key, required this.snapshot});

  final WeeklySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('This Week', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${snapshot.completionPercent}%',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: tokens.accent),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final day in snapshot.days) _DayIndicator(day: day)],
        ),
        if (snapshot.bestDayLabel != null) ...[
          SizedBox(height: tokens.spacing.space3),
          Text(
            'Best day: ${snapshot.bestDayLabel}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
        if (snapshot.insight != null) ...[
          SizedBox(height: tokens.spacing.space1),
          Text(
            snapshot.insight!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.text.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayIndicator extends StatelessWidget {
  const _DayIndicator({required this.day});

  final DaySnapshot day;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final (color, statusLabel, icon) = switch (day.status) {
      DayCompletionStatus.completed => (
        tokens.accent,
        'completed',
        Icons.check_rounded,
      ),
      DayCompletionStatus.partial => (
        tokens.accentRamp.c500,
        'partially completed',
        Icons.remove_rounded,
      ),
      DayCompletionStatus.none => (tokens.neutralRamp.c800, 'missed', null),
      DayCompletionStatus.future => (Colors.transparent, 'upcoming', null),
    };

    return Semantics(
      label: '${day.label}: $statusLabel',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: day.status == DayCompletionStatus.future
                  ? Border.all(color: tokens.neutralRamp.c700)
                  : null,
            ),
            child: icon == null
                ? null
                : Icon(icon, size: 14, color: tokens.background),
          ),
          SizedBox(height: tokens.spacing.space1),
          Text(
            day.label,
            style: TextStyle(
              fontSize: 10,
              color: tokens.text.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
