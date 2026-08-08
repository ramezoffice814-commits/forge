import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/forge_tokens.dart';
import '../../../shared/widgets/forge_empty_state.dart';
import '../../../shared/widgets/forge_error_state.dart';
import '../../../shared/widgets/forge_loading_state.dart';
import '../../../shared/widgets/forge_offline_state.dart';
import '../../../shared/widgets/forge_retry_state.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import '../../competition/presentation/providers/competition_completion_bridge.dart';
import '../../competition/presentation/widgets/dashboard_competition_snapshot.dart';
import '../../progression/presentation/providers/mission_completion_bridge.dart';
import '../domain/entities/dashboard_overview.dart';
import 'dashboard_notifier.dart';
import 'dashboard_state.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_progression_snapshot.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/discipline_overview_card.dart';
import 'widgets/league_preview_card.dart';
import 'widgets/recovery_banner.dart';
import 'widgets/today_mission_card.dart';
import 'widgets/weekly_snapshot_card.dart';

/// The Home tab's real content: the authenticated landing experience.
/// Every value rendered comes from [DashboardOverview] via
/// [dashboardNotifierProvider] — nothing here talks to a repository,
/// Supabase, or an AI provider directly. Also keeps
/// [missionCompletionBridgeProvider] alive: Dashboard is the one screen
/// that's always mounted somewhere in the authenticated shell (even while
/// `ActiveMissionPage` is pushed on top of it), so it's the natural place
/// to guarantee a real mission completion always reaches progression.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(missionCompletionBridgeProvider);
    ref.watch(competitionCompletionBridgeProvider);
    final state = ref.watch(dashboardNotifierProvider);
    return ForgeScaffold(body: _DashboardBody(state: state));
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      DashboardLoading() => const ForgeLoadingState(
        message: 'Loading your dashboard…',
      ),
      DashboardEmpty() => const ForgeEmptyState(
        icon: Icons.dashboard_outlined,
        title: 'Nothing here yet',
        message: 'Your dashboard will appear once your first day is set up.',
      ),
      DashboardOfflineNoCache() => ForgeOfflineState(
        onRetry: () => ref.read(dashboardNotifierProvider.notifier).retry(),
      ),
      DashboardErrorState(recoverable: true) => ForgeRetryState(
        title: "Couldn't load your dashboard",
        onRetry: () => ref.read(dashboardNotifierProvider.notifier).retry(),
      ),
      DashboardErrorState() => const ForgeErrorState(
        message: "We couldn't load your dashboard. Please try again later.",
      ),
      DashboardPopulated(:final overview, :final isOfflineCache) =>
        _DashboardContent(overview: overview, isOfflineCache: isOfflineCache),
    };
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.overview,
    required this.isOfflineCache,
  });

  final DashboardOverview overview;
  final bool isOfflineCache;

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    final quickActions = [
      QuickAction(
        icon: Icons.bar_chart_outlined,
        label: 'Progress',
        onTap: () => context.goNamed(AppRouteNames.progress),
      ),
      QuickAction(
        icon: Icons.emoji_events_outlined,
        label: 'Rank',
        onTap: () => context.goNamed(AppRouteNames.rank),
      ),
      QuickAction(
        icon: Icons.military_tech_outlined,
        label: 'Awards',
        onTap: () => context.goNamed(AppRouteNames.awards),
      ),
      QuickAction(
        icon: Icons.person_outline,
        label: 'Profile',
        onTap: () => context.goNamed(AppRouteNames.profile),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.space4),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 960 : constraints.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardHeader(overview: overview),
                  SizedBox(height: tokens.spacing.space3),
                  const DashboardProgressionSnapshot(),
                  SizedBox(height: tokens.spacing.space2),
                  const DashboardCompetitionSnapshot(),
                  if (isOfflineCache) ...[
                    SizedBox(height: tokens.spacing.space3),
                    _OfflineCacheBanner(lastUpdatedAt: overview.lastUpdatedAt),
                  ],
                  if (overview.recoveryModeActive) ...[
                    SizedBox(height: tokens.spacing.space4),
                    RecoveryBanner(onViewMission: () {}),
                  ],
                  SizedBox(height: tokens.spacing.space4),
                  if (isWide)
                    _WideLayout(overview: overview)
                  else
                    _NarrowLayout(overview: overview),
                  SizedBox(height: tokens.spacing.space4),
                  DashboardQuickActions(actions: quickActions),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DisciplineOverviewCard(overview: overview),
        SizedBox(height: tokens.spacing.space4),
        TodayMissionCard(mission: overview.todayMissionPreview),
        SizedBox(height: tokens.spacing.space4),
        WeeklySnapshotCard(snapshot: overview.weeklySnapshot),
        SizedBox(height: tokens.spacing.space4),
        LeaguePreviewCard(
          league: overview.league,
          onOpenRank: () => context.goNamed(AppRouteNames.rank),
        ),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TodayMissionCard(mission: overview.todayMissionPreview),
        ),
        SizedBox(width: tokens.spacing.space4),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DisciplineOverviewCard(overview: overview),
              SizedBox(height: tokens.spacing.space4),
              WeeklySnapshotCard(snapshot: overview.weeklySnapshot),
              SizedBox(height: tokens.spacing.space4),
              LeaguePreviewCard(
                league: overview.league,
                onOpenRank: () => context.goNamed(AppRouteNames.rank),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineCacheBanner extends StatelessWidget {
  const _OfflineCacheBanner({required this.lastUpdatedAt});

  final DateTime lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.space3,
          vertical: tokens.spacing.space2,
        ),
        decoration: BoxDecoration(
          color: tokens.neutralRamp.c800,
          borderRadius: tokens.radius.mdRadius,
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: tokens.text.withValues(alpha: 0.6),
            ),
            SizedBox(width: tokens.spacing.space2),
            Expanded(
              child: Text(
                "You're offline — showing your last saved dashboard.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
