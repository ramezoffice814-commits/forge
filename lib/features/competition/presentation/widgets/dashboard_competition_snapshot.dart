import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/promotion_status.dart';
import '../providers/competition_controller.dart';
import '../providers/competition_state.dart';

/// The one small, additive competition touchpoint on the Dashboard (spec
/// section 35: "current league badge, weekly rank, points to promotion —
/// keep it compact," deliberately nothing more; mission stays the page's
/// main focus). Renders nothing while competition is still loading, same
/// reasoning as `DashboardProgressionSnapshot`.
class DashboardCompetitionSnapshot extends ConsumerWidget {
  const DashboardCompetitionSnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(competitionControllerProvider);
    if (state is! CompetitionReady) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final current = state.current;
    final preview = current.movementPreview;

    final zoneLabel = switch (preview.zone) {
      PromotionStatus.promotionZone => 'Promotion zone',
      PromotionStatus.demotionZone => 'Demotion zone',
      PromotionStatus.safeZone => 'Safe zone',
    };

    return Semantics(
      button: true,
      label:
          '${current.league.name} League, rank ${preview.currentRank}, '
          '$zoneLabel, '
          '${current.weeklyScore.cappedScore.toStringAsFixed(0)} points, '
          'preview only. Opens Rank.',
      child: InkWell(
        borderRadius: tokens.radius.mdRadius,
        onTap: () => context.goNamed(AppRouteNames.rank),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: tokens.accent, size: 28),
            SizedBox(width: tokens.spacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${current.league.name} League · Rank ${preview.currentRank}',
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$zoneLabel · ${current.weeklyScore.cappedScore.toStringAsFixed(0)} '
                    'pts (preview)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
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
