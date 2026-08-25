import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../../ai_coach/domain/enums/ai_privacy_level.dart';
import '../../../ai_coach/presentation/providers/ai_coach_providers.dart';
import '../../../ai_coach/presentation/widgets/ai_mission_insight_panel.dart';
import '../../../missions/domain/aggregates/mission_lifecycle_state.dart'
    as lifecycle;
import '../../../missions/presentation/providers/mission_lifecycle_controller.dart';
import '../../../missions/presentation/providers/mission_lifecycle_state.dart';
import '../../../missions/presentation/widgets/mission_explanation_panel.dart';
import '../../domain/entities/mission_preview.dart';
import '../mission_action_label.dart';
import 'mission_transmission_frame.dart';

/// The strongest visual element on the dashboard — today's mission. The
/// primary action opens the real Daily Transmission experience
/// (`DailyTransmissionPage`) rather than a stub; status is read from the
/// mission's own event-derived `MissionAggregate`
/// (`missionLifecycleControllerProvider`) so accepting it there — or in
/// `ActiveMissionPage` — is reflected back here immediately. This replaces
/// the old `localMissionAcceptedProvider` boolean flag, which only ever
/// tracked "accepted or not" rather than the mission's real lifecycle.
class TodayMissionCard extends ConsumerWidget {
  const TodayMissionCard({
    super.key,
    required this.mission,
    required this.displayName,
  });

  final MissionPreview mission;

  /// Only for [AiMissionInsightPanel] — see that widget's doc comment
  /// for why the mission facts themselves are never passed through here.
  final String displayName;

  /// Maps the aggregate's real lifecycle onto the dashboard's simpler
  /// display bucket — but only to *advance* [mission]'s own (mock/scenario)
  /// status, never to regress it. This matters for `DashboardMockScenario`s
  /// like `completedMission`, which hardcode an advanced status (e.g.
  /// `completed`) that no event was ever actually appended for in this bare
  /// session; without this guard, a freshly-rehydrated `assigned` aggregate
  /// would incorrectly downgrade a scenario-declared `completed` mission
  /// back to `notStarted`. `abandoned`/`expired` fold back to `notStarted`:
  /// this phase doesn't yet trigger a fresh mission selection when either
  /// happens, so the safest dashboard treatment is "mission is open again".
  MissionStatus _effectiveStatus(MissionLifecycleControllerState state) {
    final isPreAcceptance =
        mission.status == MissionStatus.notStarted ||
        mission.status == MissionStatus.viewed;
    if (!isPreAcceptance || state is! MissionLifecycleReady) {
      return mission.status;
    }
    return switch (state.aggregate.lifecycleState) {
      lifecycle.MissionLifecycleState.assigned => MissionStatus.notStarted,
      lifecycle.MissionLifecycleState.viewed => MissionStatus.viewed,
      lifecycle.MissionLifecycleState.accepted ||
      lifecycle.MissionLifecycleState.active ||
      lifecycle.MissionLifecycleState.paused ||
      lifecycle.MissionLifecycleState.submitted ||
      lifecycle.MissionLifecycleState.validationFailed =>
        MissionStatus.accepted,
      lifecycle.MissionLifecycleState.completed => MissionStatus.completed,
      lifecycle.MissionLifecycleState.abandoned ||
      lifecycle.MissionLifecycleState.expired => MissionStatus.notStarted,
    };
  }

  TransmissionFrameState _frameState(MissionStatus status) {
    if (!mission.transmissionAvailable ||
        status == MissionStatus.unavailableOffline) {
      return TransmissionFrameState.unavailable;
    }
    return switch (status) {
      MissionStatus.notStarted => TransmissionFrameState.incoming,
      MissionStatus.viewed => TransmissionFrameState.revealed,
      MissionStatus.accepted => TransmissionFrameState.accepted,
      MissionStatus.readyToSubmit => TransmissionFrameState.accepted,
      MissionStatus.completed => TransmissionFrameState.completed,
      MissionStatus.unavailableOffline => TransmissionFrameState.unavailable,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final lifecycleState = ref.watch(
      missionLifecycleControllerProvider(mission.id),
    );
    final status = _effectiveStatus(lifecycleState);
    final actionEnabled = isMissionActionEnabled(status);
    final label = missionActionLabel(status);
    final opensTransmission =
        mission.transmissionAvailable && status == MissionStatus.notStarted;
    final aiEnabled =
        ref.watch(aiPrivacyLevelProvider) != AiPrivacyLevel.disabled;

    return ForgeCard(
      elevation: ForgeCardElevation.md,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TODAY'S MISSION",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message:
                      'Replay — available inside the Daily Transmission '
                      'experience',
                  child: IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                  ),
                ),
                Tooltip(
                  message:
                      'Mute — available inside the Daily Transmission '
                      'experience',
                  child: IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.space2),
        MissionTransmissionFrame(state: _frameState(status)),
        SizedBox(height: tokens.spacing.space4),
        Wrap(
          spacing: tokens.spacing.space2,
          runSpacing: tokens.spacing.space2,
          children: [
            ForgeTag(
              label: '+${mission.xpReward} XP',
              variant: ForgeTagVariant.accent,
            ),
            ForgeTag(
              label: _difficultyLabel(mission.difficulty),
              variant: ForgeTagVariant.outline,
            ),
            ForgeTag(
              label: '~${mission.estimatedMinutes} min',
              variant: ForgeTagVariant.neutral,
            ),
            ForgeTag(label: mission.category, variant: ForgeTagVariant.neutral),
            if (mission.requiresProof)
              const ForgeTag(
                label: 'Proof required',
                variant: ForgeTagVariant.outline,
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.space3),
        Text(mission.title, style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: tokens.spacing.space2),
        Text(
          mission.subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.withValues(alpha: 0.75),
          ),
        ),
        if (mission.selectionReasons.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.space3),
          MissionExplanationPanel(reasons: mission.selectionReasons),
        ],
        // Conditional on the same `ForgeCard`-children-list pattern as
        // `MissionExplanationPanel` above, not just inside the widget:
        // `ForgeCard` inserts a fixed gap before every entry after the
        // first regardless of that entry's own size, so including this
        // unconditionally would leave a dead gap whenever AI is
        // disabled — the one case a golden test actually exercises
        // (dashboard_golden_test.dart pins AI disabled deliberately, to
        // keep this screen's pixel baseline about layout, not
        // AI-generated text).
        if (aiEnabled) ...[
          SizedBox(height: tokens.spacing.space3),
          AiMissionInsightPanel(displayName: displayName),
        ],
        SizedBox(height: tokens.spacing.space4),
        ForgeButton(
          label: label,
          onPressed: actionEnabled
              ? () {
                  if (opensTransmission) {
                    context.pushNamed(AppRouteNames.dailyTransmission);
                    return;
                  }
                  context.pushNamed(
                    AppRouteNames.activeMission,
                    pathParameters: {'missionInstanceId': mission.id},
                  );
                }
              : null,
        ),
      ],
    );
  }

  static String _difficultyLabel(MissionDifficulty difficulty) {
    return switch (difficulty) {
      MissionDifficulty.easy => 'Easy',
      MissionDifficulty.moderate => 'Moderate',
      MissionDifficulty.hard => 'Hard',
    };
  }
}
