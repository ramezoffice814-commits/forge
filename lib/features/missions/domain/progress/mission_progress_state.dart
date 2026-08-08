import 'package:flutter/foundation.dart';

import 'mission_progress_definition.dart';
import 'mission_progress_type.dart';

/// Current progress — the "how far along" side, distinct from the
/// [MissionProgressDefinition] target it's measured against. Reconstructed
/// by folding `MissionProgressUpdated` events, never mutated in place.
@immutable
sealed class MissionProgressState {
  const MissionProgressState();

  MissionProgressType get type;

  /// Builds the zeroed starting state for a freshly-accepted mission.
  static MissionProgressState initial(MissionProgressDefinition definition) {
    return switch (definition) {
      BinaryProgressDefinition() => const BinaryProgressState(completed: false),
      CounterProgressDefinition(:final targetCount, :final unit) =>
        CounterProgressState(
          currentCount: 0,
          targetCount: targetCount,
          unit: unit,
        ),
      TimerProgressDefinition(:final targetDuration) => TimerProgressState(
        accumulatedDuration: Duration.zero,
        targetDuration: targetDuration,
      ),
      ChecklistProgressDefinition(:final items) => ChecklistProgressState(
        items: items,
        completedItemIds: const {},
      ),
      PercentageProgressDefinition(:final thresholdPercentage) =>
        PercentageProgressState(
          percentage: 0,
          thresholdPercentage: thresholdPercentage,
        ),
      QuantityProgressDefinition(:final targetValue, :final unit) =>
        QuantityProgressState(
          currentValue: 0,
          targetValue: targetValue,
          unit: unit,
        ),
      ReflectionProgressDefinition(:final minimumLength) =>
        ReflectionProgressState(
          minimumLength: minimumLength,
          responseLength: 0,
          responsePresent: false,
        ),
      ReadingProgressDefinition(:final targetDuration) => ReadingProgressState(
        durationRead: Duration.zero,
        targetDuration: targetDuration,
      ),
      CodingSessionProgressDefinition(
        :final targetDuration,
        :final checklist,
      ) =>
        CodingSessionProgressState(
          accumulatedActiveDuration: Duration.zero,
          targetDuration: targetDuration,
          checklist: checklist,
          completedItemIds: const {},
        ),
      HydrationProgressDefinition(:final targetServings) =>
        HydrationProgressState(
          currentServings: 0,
          targetServings: targetServings,
        ),
    };
  }
}

final class BinaryProgressState extends MissionProgressState {
  const BinaryProgressState({required this.completed});

  final bool completed;

  @override
  MissionProgressType get type => MissionProgressType.binary;
}

final class CounterProgressState extends MissionProgressState {
  const CounterProgressState({
    required this.currentCount,
    required this.targetCount,
    this.unit = 'reps',
  });

  final int currentCount;
  final int targetCount;
  final String unit;

  bool get isComplete => currentCount >= targetCount;

  @override
  MissionProgressType get type => MissionProgressType.counter;
}

final class TimerProgressState extends MissionProgressState {
  const TimerProgressState({
    required this.accumulatedDuration,
    required this.targetDuration,
  });

  final Duration accumulatedDuration;
  final Duration targetDuration;

  bool get isComplete => accumulatedDuration >= targetDuration;

  @override
  MissionProgressType get type => MissionProgressType.timer;
}

final class ChecklistProgressState extends MissionProgressState {
  const ChecklistProgressState({
    required this.items,
    required this.completedItemIds,
  });

  final List<ChecklistItemDefinition> items;
  final Set<String> completedItemIds;

  bool get isComplete =>
      items.isNotEmpty &&
      items.every((item) => completedItemIds.contains(item.id));

  @override
  MissionProgressType get type => MissionProgressType.checklist;
}

final class PercentageProgressState extends MissionProgressState {
  const PercentageProgressState({
    required this.percentage,
    required this.thresholdPercentage,
  });

  final double percentage;
  final double thresholdPercentage;

  bool get isComplete => percentage >= thresholdPercentage;

  @override
  MissionProgressType get type => MissionProgressType.percentage;
}

final class QuantityProgressState extends MissionProgressState {
  const QuantityProgressState({
    required this.currentValue,
    required this.targetValue,
    this.unit = 'units',
  });

  final num currentValue;
  final num targetValue;
  final String unit;

  bool get isComplete => currentValue >= targetValue;

  @override
  MissionProgressType get type => MissionProgressType.quantity;
}

/// Never carries the actual reflection text — only whether a response
/// exists and how long it is. See the privacy notes in
/// `MissionCompletionValidator`.
final class ReflectionProgressState extends MissionProgressState {
  const ReflectionProgressState({
    required this.minimumLength,
    required this.responseLength,
    required this.responsePresent,
  });

  final int minimumLength;
  final int responseLength;
  final bool responsePresent;

  bool get isComplete => responsePresent && responseLength >= minimumLength;

  @override
  MissionProgressType get type => MissionProgressType.reflection;
}

final class ReadingProgressState extends MissionProgressState {
  const ReadingProgressState({
    required this.durationRead,
    required this.targetDuration,
  });

  final Duration durationRead;
  final Duration targetDuration;

  bool get isComplete => durationRead >= targetDuration;

  @override
  MissionProgressType get type => MissionProgressType.reading;
}

final class CodingSessionProgressState extends MissionProgressState {
  const CodingSessionProgressState({
    required this.accumulatedActiveDuration,
    required this.targetDuration,
    this.checklist = const [],
    this.completedItemIds = const {},
  });

  final Duration accumulatedActiveDuration;
  final Duration targetDuration;
  final List<ChecklistItemDefinition> checklist;
  final Set<String> completedItemIds;

  bool get isComplete =>
      accumulatedActiveDuration >= targetDuration &&
      checklist.every((item) => completedItemIds.contains(item.id));

  @override
  MissionProgressType get type => MissionProgressType.codingSession;
}

final class HydrationProgressState extends MissionProgressState {
  const HydrationProgressState({
    required this.currentServings,
    required this.targetServings,
  });

  final int currentServings;
  final int targetServings;

  bool get isComplete => currentServings >= targetServings;

  @override
  MissionProgressType get type => MissionProgressType.hydration;
}
