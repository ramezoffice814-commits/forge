import 'package:flutter/foundation.dart';

import 'mission_progress_type.dart';

@immutable
class ChecklistItemDefinition {
  const ChecklistItemDefinition({required this.id, required this.label});

  final String id;
  final String label;
}

/// What a mission *requires* — the target side of progress. Declared by the
/// catalog (via `MissionDefinition.progressType`/`progressTarget`) and
/// carried onto the `MissionInstance`, so the UI and the validator always
/// agree on what "done" means for this specific mission.
@immutable
sealed class MissionProgressDefinition {
  const MissionProgressDefinition();

  MissionProgressType get type;

  /// Builds the right definition from catalog data. [resolvedMinutes] is
  /// the engine-resolved duration (never a static catalog field) for the
  /// duration-based types; [completionConditions] becomes the checklist's
  /// items when [type] is [MissionProgressType.checklist].
  static MissionProgressDefinition fromCatalog({
    required MissionProgressType type,
    required int? target,
    required int resolvedMinutes,
    required List<String> completionConditions,
  }) {
    switch (type) {
      case MissionProgressType.binary:
        return const BinaryProgressDefinition();
      case MissionProgressType.counter:
        return CounterProgressDefinition(targetCount: target ?? 10);
      case MissionProgressType.timer:
        return TimerProgressDefinition(
          targetDuration: Duration(minutes: resolvedMinutes),
        );
      case MissionProgressType.checklist:
        return ChecklistProgressDefinition(
          items: [
            for (var i = 0; i < completionConditions.length; i++)
              ChecklistItemDefinition(
                id: 'item-$i',
                label: completionConditions[i],
              ),
          ],
        );
      case MissionProgressType.percentage:
        return PercentageProgressDefinition(
          thresholdPercentage: (target ?? 100).toDouble(),
        );
      case MissionProgressType.quantity:
        return QuantityProgressDefinition(targetValue: target ?? 1);
      case MissionProgressType.reflection:
        return ReflectionProgressDefinition(minimumLength: target ?? 10);
      case MissionProgressType.reading:
        return ReadingProgressDefinition(
          targetDuration: Duration(minutes: resolvedMinutes),
        );
      case MissionProgressType.codingSession:
        return CodingSessionProgressDefinition(
          targetDuration: Duration(minutes: resolvedMinutes),
        );
      case MissionProgressType.hydration:
        return HydrationProgressDefinition(targetServings: target ?? 1);
    }
  }
}

final class BinaryProgressDefinition extends MissionProgressDefinition {
  const BinaryProgressDefinition();

  @override
  MissionProgressType get type => MissionProgressType.binary;
}

final class CounterProgressDefinition extends MissionProgressDefinition {
  const CounterProgressDefinition({
    required this.targetCount,
    this.unit = 'reps',
  });

  final int targetCount;
  final String unit;

  @override
  MissionProgressType get type => MissionProgressType.counter;
}

final class TimerProgressDefinition extends MissionProgressDefinition {
  const TimerProgressDefinition({required this.targetDuration});

  final Duration targetDuration;

  @override
  MissionProgressType get type => MissionProgressType.timer;
}

final class ChecklistProgressDefinition extends MissionProgressDefinition {
  const ChecklistProgressDefinition({required this.items});

  final List<ChecklistItemDefinition> items;

  @override
  MissionProgressType get type => MissionProgressType.checklist;
}

final class PercentageProgressDefinition extends MissionProgressDefinition {
  const PercentageProgressDefinition({this.thresholdPercentage = 100});

  final double thresholdPercentage;

  @override
  MissionProgressType get type => MissionProgressType.percentage;
}

final class QuantityProgressDefinition extends MissionProgressDefinition {
  const QuantityProgressDefinition({
    required this.targetValue,
    this.unit = 'units',
  });

  final num targetValue;
  final String unit;

  @override
  MissionProgressType get type => MissionProgressType.quantity;
}

final class ReflectionProgressDefinition extends MissionProgressDefinition {
  const ReflectionProgressDefinition({this.minimumLength = 10});

  final int minimumLength;

  @override
  MissionProgressType get type => MissionProgressType.reflection;
}

/// Duration-based (not page-based) reading progress — see the type doc for
/// why this phase picked one of the spec's two suggested reading shapes.
final class ReadingProgressDefinition extends MissionProgressDefinition {
  const ReadingProgressDefinition({required this.targetDuration});

  final Duration targetDuration;

  @override
  MissionProgressType get type => MissionProgressType.reading;
}

final class CodingSessionProgressDefinition extends MissionProgressDefinition {
  const CodingSessionProgressDefinition({
    required this.targetDuration,
    this.checklist = const [],
  });

  final Duration targetDuration;
  final List<ChecklistItemDefinition> checklist;

  @override
  MissionProgressType get type => MissionProgressType.codingSession;
}

final class HydrationProgressDefinition extends MissionProgressDefinition {
  const HydrationProgressDefinition({required this.targetServings});

  final int targetServings;

  @override
  MissionProgressType get type => MissionProgressType.hydration;
}
