import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/events/mission_event.dart';

/// Renders a mission's event history, most recent first. Deliberately shows
/// only a friendly label and a timestamp per event — never an idempotency
/// key, raw event id, or (per `ReflectionProgressState`'s own privacy rule)
/// any actual reflection text, since that never exists on an event to begin
/// with.
class MissionTimeline extends StatelessWidget {
  const MissionTimeline({super.key, required this.events});

  final List<MissionEvent> events;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    if (events.isEmpty) return const SizedBox.shrink();
    final reversed = events.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in reversed)
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.space1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _iconFor(event),
                  size: 18,
                  color: tokens.text.withValues(alpha: 0.6),
                ),
                SizedBox(width: tokens.spacing.space2),
                Expanded(
                  child: Text(
                    _labelFor(event),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  _formatTime(event.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static IconData _iconFor(MissionEvent event) => switch (event) {
    MissionAssigned() => Icons.flag_outlined,
    MissionViewed() => Icons.visibility_outlined,
    MissionAccepted() => Icons.check_circle_outline_rounded,
    MissionStarted() => Icons.play_circle_outline_rounded,
    MissionProgressUpdated() => Icons.trending_up_rounded,
    MissionPaused() => Icons.pause_circle_outline_rounded,
    MissionResumed() => Icons.play_circle_outline_rounded,
    MissionSubmitted() => Icons.send_outlined,
    MissionValidationPassed() => Icons.verified_outlined,
    MissionValidationFailed() => Icons.error_outline_rounded,
    MissionCompleted() => Icons.emoji_events_outlined,
    MissionCompletionUndone() => Icons.undo_rounded,
    MissionRejected() => Icons.cancel_outlined,
    MissionEasierRequested() => Icons.trending_down_rounded,
    MissionCategoryChangeRequested() => Icons.swap_horiz_rounded,
    MissionAbandoned() => Icons.stop_circle_outlined,
    MissionExpired() => Icons.timer_off_outlined,
    MissionSyncQueued() => Icons.cloud_upload_outlined,
    MissionSyncConfirmed() => Icons.cloud_done_outlined,
    MissionSyncFailed() => Icons.cloud_off_outlined,
  };

  static String _labelFor(MissionEvent event) => switch (event) {
    MissionAssigned() => 'Mission assigned',
    MissionViewed() => 'Mission viewed',
    MissionAccepted() => 'Mission accepted',
    MissionStarted() => 'Started working',
    MissionProgressUpdated(:final isCorrection) =>
      isCorrection ? 'Progress corrected' : 'Progress updated',
    MissionPaused() => 'Paused',
    MissionResumed() => 'Resumed',
    MissionSubmitted() => 'Submitted for validation',
    MissionValidationPassed() => 'Validation passed',
    MissionValidationFailed(:final userFacingExplanation) =>
      userFacingExplanation ?? 'Validation failed',
    MissionCompleted() => 'Mission completed',
    MissionCompletionUndone() => 'Completion undone',
    MissionRejected() => 'Mission rejected',
    MissionEasierRequested() => 'Requested an easier mission',
    MissionCategoryChangeRequested(:final requestedCategory) =>
      'Requested category: ${requestedCategory.name}',
    MissionAbandoned() => 'Mission abandoned',
    MissionExpired() => 'Mission expired',
    MissionSyncQueued() => 'Queued for sync',
    MissionSyncConfirmed() => 'Sync confirmed',
    MissionSyncFailed() => 'Sync failed — will retry',
  };
}
