import '../../features/missions/domain/progress/mission_progress_state.dart';

/// Maps a local [MissionProgressState] into the `{progressType, progress}`
/// shape `supabase/functions/_shared/progress.ts` and
/// `forge_validate_completion` (in `supabase/migrations/
/// 20260817090100_mission_reward_functions.sql`) expect — the one place
/// that field-name convention is defined on the Dart side, so a rename on
/// either side has exactly one place to fix on this side.
class MissionProgressPayload {
  const MissionProgressPayload({
    required this.progressType,
    required this.progress,
  });

  final String progressType;
  final Map<String, Object?> progress;

  Map<String, Object?> toCommandFields() => {
    'progressType': progressType,
    'progress': progress,
  };
}

MissionProgressPayload mapMissionProgressToPayload(MissionProgressState state) {
  return switch (state) {
    BinaryProgressState(:final completed) => MissionProgressPayload(
      progressType: 'binary',
      progress: {'completed': completed},
    ),
    CounterProgressState(:final currentCount, :final targetCount) =>
      MissionProgressPayload(
        progressType: 'counter',
        progress: {'currentCount': currentCount, 'targetCount': targetCount},
      ),
    QuantityProgressState(:final currentValue, :final targetValue) =>
      MissionProgressPayload(
        progressType: 'quantity',
        progress: {'currentValue': currentValue, 'targetValue': targetValue},
      ),
    HydrationProgressState(:final currentServings, :final targetServings) =>
      MissionProgressPayload(
        progressType: 'hydration',
        progress: {
          'currentServings': currentServings,
          'targetServings': targetServings,
        },
      ),
    PercentageProgressState(:final percentage, :final thresholdPercentage) =>
      MissionProgressPayload(
        progressType: 'percentage',
        progress: {
          'percentage': percentage,
          'thresholdPercentage': thresholdPercentage,
        },
      ),
    TimerProgressState(:final accumulatedDuration, :final targetDuration) =>
      MissionProgressPayload(
        progressType: 'timer',
        progress: {
          'accumulatedSeconds': accumulatedDuration.inSeconds,
          'targetSeconds': targetDuration.inSeconds,
        },
      ),
    ReadingProgressState(:final durationRead, :final targetDuration) =>
      MissionProgressPayload(
        progressType: 'reading',
        progress: {
          'durationReadSeconds': durationRead.inSeconds,
          'targetSeconds': targetDuration.inSeconds,
        },
      ),
    ChecklistProgressState(:final items, :final completedItemIds) =>
      MissionProgressPayload(
        progressType: 'checklist',
        progress: {
          'itemIds': items.map((i) => i.id).toList(),
          'completedItemIds': completedItemIds.toList(),
        },
      ),
    CodingSessionProgressState(
      :final accumulatedActiveDuration,
      :final targetDuration,
      :final checklist,
      :final completedItemIds,
    ) =>
      MissionProgressPayload(
        progressType: 'codingSession',
        progress: {
          'activeSeconds': accumulatedActiveDuration.inSeconds,
          'targetSeconds': targetDuration.inSeconds,
          'itemIds': checklist.map((i) => i.id).toList(),
          'completedItemIds': completedItemIds.toList(),
        },
      ),
    ReflectionProgressState(
      :final responseLength,
      :final responsePresent,
      :final minimumLength,
    ) =>
      MissionProgressPayload(
        progressType: 'reflection',
        progress: {
          'responseLength': responseLength,
          'responsePresent': responsePresent,
          'minimumLength': minimumLength,
        },
      ),
  };
}
