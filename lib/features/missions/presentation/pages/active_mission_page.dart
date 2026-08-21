import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/authority_status_badge.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_empty_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../../../../shared/widgets/sync_conflict_banner.dart';
import '../../domain/aggregates/mission_aggregate.dart';
import '../../domain/aggregates/mission_transition_failure.dart';
import '../../domain/enums/mission_category.dart';
import '../providers/mission_backend_sync_bridge.dart';
import '../providers/mission_lifecycle_controller.dart';
import '../providers/mission_lifecycle_state.dart';
import '../widgets/mission_action_bar.dart';
import '../widgets/mission_progress_control.dart';
import '../widgets/mission_timeline.dart';

/// The full-screen "working on a mission" experience — pushed from the
/// Dashboard (or reached back via a deep link). Every action here delegates
/// to `MissionLifecycleController`; this page only decides *what to show*
/// for a given `MissionLifecycleControllerState`, never *whether an action
/// is legal*.
class ActiveMissionPage extends ConsumerStatefulWidget {
  const ActiveMissionPage({super.key, required this.missionInstanceId});

  final String missionInstanceId;

  @override
  ConsumerState<ActiveMissionPage> createState() => _ActiveMissionPageState();
}

class _ActiveMissionPageState extends ConsumerState<ActiveMissionPage> {
  @override
  void initState() {
    super.initState();
    // Deferred: a Notifier's state can't be mutated while the tree that
    // reads it is still building (see MissionSelectionController for the
    // same pattern elsewhere in this feature).
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(
            missionLifecycleControllerProvider(
              widget.missionInstanceId,
            ).notifier,
          )
          .view();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      missionLifecycleControllerProvider(widget.missionInstanceId),
    );

    return switch (state) {
      MissionLifecycleLoading() => const ForgeScaffold(
        body: ForgeLoadingState(message: 'Loading mission…'),
      ),
      MissionLifecycleNotFound() => ForgeScaffold(
        appBarTitle: 'Mission',
        body: ForgeEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Mission not found',
          message: "This mission isn't available anymore.",
        ),
      ),
      MissionLifecycleReady(:final aggregate, :final lastFailure) =>
        _ActiveMissionContent(
          missionInstanceId: widget.missionInstanceId,
          aggregate: aggregate,
          lastFailure: lastFailure,
        ),
    };
  }
}

class _ActiveMissionContent extends ConsumerWidget {
  const _ActiveMissionContent({
    required this.missionInstanceId,
    required this.aggregate,
    required this.lastFailure,
  });

  final String missionInstanceId;
  final MissionAggregate aggregate;
  final MissionTransitionFailure? lastFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final notifier = ref.read(
      missionLifecycleControllerProvider(missionInstanceId).notifier,
    );
    final instance = aggregate.instance;
    final syncState = ref.watch(
      missionBackendSyncControllerProvider(missionInstanceId),
    );

    return ForgeScaffold(
      appBarTitle: instance.title,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastFailure != null) ...[
              _FailureBanner(
                failure: lastFailure!,
                onDismiss: notifier.dismissFailure,
              ),
              SizedBox(height: tokens.spacing.space3),
            ],
            if (syncState.lastErrorUx != null &&
                syncState.status == MissionSyncStatus.conflict) ...[
              SyncConflictBanner(state: syncState.lastErrorUx!),
              SizedBox(height: tokens.spacing.space3),
            ],
            ForgeCard(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      missionCategoryLabel(instance.category),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: tokens.accent),
                    ),
                    if (syncState.status != MissionSyncStatus.idle)
                      AuthorityStatusBadge(
                        indicator: switch (syncState.status) {
                          MissionSyncStatus.idle =>
                            AuthorityIndicator.provisional,
                          MissionSyncStatus.queued =>
                            AuthorityIndicator.provisional,
                          MissionSyncStatus.syncing =>
                            AuthorityIndicator.pendingSync,
                          MissionSyncStatus.confirmed =>
                            AuthorityIndicator.confirmed,
                          MissionSyncStatus.rejected =>
                            AuthorityIndicator.conflict,
                          MissionSyncStatus.conflict =>
                            AuthorityIndicator.conflict,
                        },
                      ),
                  ],
                ),
                Text(
                  instance.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${instance.resolvedDuration} min · +${instance.xpHint} XP hint',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.space4),
            ForgeCard(
              children: [
                Text('Progress', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: tokens.spacing.space2),
                MissionProgressControl(
                  progress: aggregate.progressState,
                  enabled: aggregate.canUpdateProgress,
                  onUpdate: (proposed, {isCorrection = false}) => notifier
                      .updateProgress(proposed, isCorrection: isCorrection),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.space4),
            MissionActionBar(
              aggregate: aggregate,
              onAccept: notifier.accept,
              onStart: notifier.start,
              onPause: notifier.pause,
              onResume: notifier.resume,
              onSubmit: notifier.submit,
              onReject: notifier.reject,
              onAbandon: notifier.abandon,
              onUndoCompletion: notifier.undoCompletion,
            ),
            SizedBox(height: tokens.spacing.space4),
            ForgeCard(
              children: [
                Text('History', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: tokens.spacing.space2),
                MissionTimeline(events: aggregate.events),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onDismiss});

  final MissionTransitionFailure failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.space3),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: tokens.radius.mdRadius,
        border: Border.all(color: const Color(0xFFEF4444)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
          SizedBox(width: tokens.spacing.space2),
          Expanded(
            child: Text(
              failure.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onDismiss,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
