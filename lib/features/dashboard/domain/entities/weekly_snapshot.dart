import 'package:flutter/foundation.dart';

enum DayCompletionStatus { none, partial, completed, future }

@immutable
class DaySnapshot {
  const DaySnapshot({required this.label, required this.status});

  /// Single-letter day label ("M", "T", ...) — not a full weekday name, to
  /// keep the 7-indicator row compact on small screens.
  final String label;
  final DayCompletionStatus status;
}

@immutable
class WeeklySnapshot {
  const WeeklySnapshot({
    required this.days,
    required this.completionPercent,
    this.bestDayLabel,
    this.insight,
  });

  /// Exactly 7 entries, Monday through Sunday.
  final List<DaySnapshot> days;
  final int completionPercent;
  final String? bestDayLabel;
  final String? insight;
}
