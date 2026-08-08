import '../progress/mission_progress_state.dart';

enum ValidationOutcome { passed, failed }

/// Local, provisional-only validation of whether a mission's current
/// progress satisfies its own definition. Never grants anything — a future
/// server independently re-validates before any reward is confirmed (see
/// the trust-boundary notes on `MissionRewardState`).
class ValidationResult {
  const ValidationResult({
    required this.outcome,
    this.reasonCodes = const [],
    this.userFacingExplanation,
    this.requiredRemainingProgress,
    this.provisionalOnly = true,
  });

  final ValidationOutcome outcome;
  final List<String> reasonCodes;
  final String? userFacingExplanation;
  final String? requiredRemainingProgress;
  final bool provisionalOnly;

  bool get passed => outcome == ValidationOutcome.passed;
}

abstract final class MissionCompletionValidator {
  static ValidationResult validate(MissionProgressState progress) {
    return switch (progress) {
      BinaryProgressState(:final completed) =>
        completed
            ? _passed()
            : _failed(
                const ['binaryNotCompleted'],
                'Mark the mission as done to submit.',
                'Not yet marked complete',
              ),
      CounterProgressState(
        :final currentCount,
        :final targetCount,
        :final unit,
      ) =>
        currentCount >= targetCount
            ? _passed()
            : _failed(
                const ['counterBelowTarget'],
                'You still have ${targetCount - currentCount} $unit remaining.',
                '${targetCount - currentCount} $unit remaining',
              ),
      TimerProgressState(:final accumulatedDuration, :final targetDuration) =>
        accumulatedDuration >= targetDuration
            ? _passed()
            : _failed(
                const ['timerBelowTarget'],
                'Keep going — ${_format(targetDuration - accumulatedDuration)} left.',
                '${_format(targetDuration - accumulatedDuration)} remaining',
              ),
      ChecklistProgressState(:final items, :final completedItemIds) =>
        items.isNotEmpty && items.every((i) => completedItemIds.contains(i.id))
            ? _passed()
            : _failed(
                const ['checklistIncomplete'],
                'Finish the remaining checklist items.',
                '${items.length - completedItemIds.length} item(s) remaining',
              ),
      PercentageProgressState(:final percentage, :final thresholdPercentage) =>
        percentage >= thresholdPercentage
            ? _passed()
            : _failed(
                const ['percentageBelowThreshold'],
                'Reach ${thresholdPercentage.round()}% to submit.',
                '${(thresholdPercentage - percentage).round()}% remaining',
              ),
      QuantityProgressState(
        :final currentValue,
        :final targetValue,
        :final unit,
      ) =>
        currentValue >= targetValue
            ? _passed()
            : _failed(
                const ['quantityBelowTarget'],
                'You still need ${targetValue - currentValue} more $unit.',
                '${targetValue - currentValue} $unit remaining',
              ),
      ReflectionProgressState(
        :final responsePresent,
        :final responseLength,
        :final minimumLength,
      ) =>
        (responsePresent && responseLength >= minimumLength)
            ? _passed()
            : _failed(
                const ['reflectionTooShort'],
                'Add a little more detail to your reflection.',
                null,
              ),
      ReadingProgressState(:final durationRead, :final targetDuration) =>
        durationRead >= targetDuration
            ? _passed()
            : _failed(
                const ['readingBelowTarget'],
                'Keep reading — ${_format(targetDuration - durationRead)} left.',
                '${_format(targetDuration - durationRead)} remaining',
              ),
      CodingSessionProgressState(
        :final accumulatedActiveDuration,
        :final targetDuration,
        :final checklist,
        :final completedItemIds,
      ) =>
        (accumulatedActiveDuration >= targetDuration &&
                checklist.every((i) => completedItemIds.contains(i.id)))
            ? _passed()
            : _failed(
                const ['codingSessionIncomplete'],
                'Finish the remaining session time or checklist items.',
                null,
              ),
      HydrationProgressState(:final currentServings, :final targetServings) =>
        currentServings >= targetServings
            ? _passed()
            : _failed(
                const ['hydrationBelowTarget'],
                'You still need ${targetServings - currentServings} more serving(s).',
                '${targetServings - currentServings} remaining',
              ),
    };
  }

  static ValidationResult _passed() =>
      const ValidationResult(outcome: ValidationOutcome.passed);

  static ValidationResult _failed(
    List<String> reasonCodes,
    String explanation,
    String? remaining,
  ) {
    return ValidationResult(
      outcome: ValidationOutcome.failed,
      reasonCodes: reasonCodes,
      userFacingExplanation: explanation,
      requiredRemainingProgress: remaining,
    );
  }

  static String _format(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final minutes = clamped.inMinutes;
    final seconds = clamped.inSeconds % 60;
    return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
  }
}
