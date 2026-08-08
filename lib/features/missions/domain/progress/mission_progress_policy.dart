import 'mission_progress_state.dart';

enum ProgressUpdateOutcome { accepted, rejected }

class ProgressUpdateResult {
  const ProgressUpdateResult({
    required this.outcome,
    required this.normalizedState,
    this.reasonCodes = const [],
  });

  final ProgressUpdateOutcome outcome;
  final MissionProgressState normalizedState;
  final List<String> reasonCodes;

  bool get isAccepted => outcome == ProgressUpdateOutcome.accepted;
}

/// Validates a *proposed* progress update against the current state before
/// it's allowed to become a `MissionProgressUpdated` event. Every numeric
/// type shares the same shape of rule (never negative, capped, monotonic
/// unless explicitly a correction) — kept as one policy rather than one
/// class per type, since the actual rules don't differ enough to justify it.
abstract final class MissionProgressPolicy {
  static const maxCounterValue = 100000;
  static const maxQuantityValue = 100000;
  static const maxHydrationServings = 50;
  static const maxReflectionLength = 5000;

  /// A single unverified timer/reading/coding-session interval is capped
  /// here as a policy-level safety net — session-level enforcement lives in
  /// `MissionSessionPolicy`, this is the last line of defense against a
  /// clearly-impossible jump (e.g. a clock anomaly).
  static const maxSingleIntervalJump = Duration(hours: 3);

  static ProgressUpdateResult evaluate({
    required MissionProgressState current,
    required MissionProgressState proposed,
    bool isCorrection = false,
  }) {
    if (current.type != proposed.type) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: current,
        reasonCodes: const ['mismatchedProgressType'],
      );
    }

    return switch (proposed) {
      BinaryProgressState() => ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.accepted,
        normalizedState: proposed,
      ),
      CounterProgressState() => _numeric(
        current: (current as CounterProgressState).currentCount,
        proposedValue: proposed.currentCount,
        max: maxCounterValue,
        isCorrection: isCorrection,
        rebuild: (v) => CounterProgressState(
          currentCount: v.round(),
          targetCount: proposed.targetCount,
          unit: proposed.unit,
        ),
      ),
      QuantityProgressState() => _numeric(
        current: (current as QuantityProgressState).currentValue,
        proposedValue: proposed.currentValue,
        max: maxQuantityValue,
        isCorrection: isCorrection,
        rebuild: (v) => QuantityProgressState(
          currentValue: v,
          targetValue: proposed.targetValue,
          unit: proposed.unit,
        ),
      ),
      HydrationProgressState() => _numeric(
        current: (current as HydrationProgressState).currentServings,
        proposedValue: proposed.currentServings,
        max: maxHydrationServings,
        isCorrection: isCorrection,
        rebuild: (v) => HydrationProgressState(
          currentServings: v.round(),
          targetServings: proposed.targetServings,
        ),
      ),
      PercentageProgressState() => _numeric(
        current: (current as PercentageProgressState).percentage,
        proposedValue: proposed.percentage,
        max: 100,
        isCorrection: isCorrection,
        rebuild: (v) => PercentageProgressState(
          percentage: v.toDouble(),
          thresholdPercentage: proposed.thresholdPercentage,
        ),
      ),
      TimerProgressState() => _duration(
        current: (current as TimerProgressState).accumulatedDuration,
        proposedValue: proposed.accumulatedDuration,
        isCorrection: isCorrection,
        rebuild: (d) => TimerProgressState(
          accumulatedDuration: d,
          targetDuration: proposed.targetDuration,
        ),
      ),
      ReadingProgressState() => _duration(
        current: (current as ReadingProgressState).durationRead,
        proposedValue: proposed.durationRead,
        isCorrection: isCorrection,
        rebuild: (d) => ReadingProgressState(
          durationRead: d,
          targetDuration: proposed.targetDuration,
        ),
      ),
      CodingSessionProgressState() => _codingSession(
        current as CodingSessionProgressState,
        proposed,
        isCorrection,
      ),
      ChecklistProgressState() => _checklist(
        current as ChecklistProgressState,
        proposed,
      ),
      ReflectionProgressState() => _reflection(proposed),
    };
  }

  static ProgressUpdateResult _numeric({
    required num current,
    required num proposedValue,
    required num max,
    required bool isCorrection,
    required MissionProgressState Function(num) rebuild,
  }) {
    if (proposedValue < current && !isCorrection) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: rebuild(current),
        reasonCodes: const ['decreaseRequiresCorrection'],
      );
    }
    final normalized = proposedValue.clamp(0, max);
    return ProgressUpdateResult(
      outcome: ProgressUpdateOutcome.accepted,
      normalizedState: rebuild(normalized),
    );
  }

  static ProgressUpdateResult _duration({
    required Duration current,
    required Duration proposedValue,
    required bool isCorrection,
    required MissionProgressState Function(Duration) rebuild,
  }) {
    if (proposedValue < current && !isCorrection) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: rebuild(current),
        reasonCodes: const ['decreaseRequiresCorrection'],
      );
    }
    final delta = proposedValue - current;
    if (delta > maxSingleIntervalJump) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: rebuild(current),
        reasonCodes: const ['implausibleDurationJump'],
      );
    }
    final normalized = proposedValue.isNegative ? Duration.zero : proposedValue;
    return ProgressUpdateResult(
      outcome: ProgressUpdateOutcome.accepted,
      normalizedState: rebuild(normalized),
    );
  }

  static ProgressUpdateResult _checklist(
    ChecklistProgressState current,
    ChecklistProgressState proposed,
  ) {
    final validIds = current.items.map((i) => i.id).toSet();
    if (!validIds.containsAll(proposed.completedItemIds)) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: current,
        reasonCodes: const ['unknownChecklistItem'],
      );
    }
    return ProgressUpdateResult(
      outcome: ProgressUpdateOutcome.accepted,
      normalizedState: proposed,
    );
  }

  static ProgressUpdateResult _codingSession(
    CodingSessionProgressState current,
    CodingSessionProgressState proposed,
    bool isCorrection,
  ) {
    final proposedDuration = proposed.accumulatedActiveDuration;
    final currentDuration = current.accumulatedActiveDuration;

    if (proposedDuration < currentDuration && !isCorrection) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: current,
        reasonCodes: const ['decreaseRequiresCorrection'],
      );
    }
    if (proposedDuration - currentDuration > maxSingleIntervalJump) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: current,
        reasonCodes: const ['implausibleDurationJump'],
      );
    }

    final validIds = current.checklist.map((i) => i.id).toSet();
    if (!validIds.containsAll(proposed.completedItemIds)) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: current,
        reasonCodes: const ['unknownChecklistItem'],
      );
    }

    return ProgressUpdateResult(
      outcome: ProgressUpdateOutcome.accepted,
      normalizedState: CodingSessionProgressState(
        accumulatedActiveDuration: proposedDuration.isNegative
            ? Duration.zero
            : proposedDuration,
        targetDuration: proposed.targetDuration,
        checklist: proposed.checklist,
        completedItemIds: proposed.completedItemIds,
      ),
    );
  }

  static ProgressUpdateResult _reflection(ReflectionProgressState proposed) {
    if (proposed.responseLength < 0 ||
        proposed.responseLength > maxReflectionLength) {
      return ProgressUpdateResult(
        outcome: ProgressUpdateOutcome.rejected,
        normalizedState: proposed,
        reasonCodes: const ['invalidReflectionLength'],
      );
    }
    return ProgressUpdateResult(
      outcome: ProgressUpdateOutcome.accepted,
      normalizedState: proposed,
    );
  }
}
