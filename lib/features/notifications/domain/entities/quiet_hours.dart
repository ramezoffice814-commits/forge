import 'package:flutter/foundation.dart';

/// User-configured quiet hours (Roadmap Item 15 section 9). Deliberately
/// evaluated against whatever `DateTime` the caller passes in as
/// *already local* — every call site in this app passes `DateTime.now()`
/// (which is local by Dart's own definition), never a UTC instant, so
/// there is no separate timezone-conversion step to get wrong here. The
/// `timezone` IANA string persisted alongside this (see
/// `NotificationPreferences`) is a record of which zone the minutes
/// below mean, for any future server-side scheduling that would need
/// it — this class itself never touches it.
@immutable
class QuietHours {
  const QuietHours({
    required this.enabled,
    required this.startMinute,
    required this.endMinute,
  }) : assert(startMinute >= 0 && startMinute < 1440),
       assert(endMinute >= 0 && endMinute < 1440);

  final bool enabled;

  /// Minutes since local midnight, e.g. 22:30 -> 1350.
  final int startMinute;

  /// Minutes since local midnight, e.g. 07:00 -> 420.
  final int endMinute;

  /// Whether [localNow] falls inside the configured window — correctly
  /// handles the overnight case (`start > end`, e.g. 22:30 -> 07:00) by
  /// treating it as "before end OR after-or-at start" instead of the
  /// same-day "after start AND before end" test a same-day window uses.
  bool isQuietAt(DateTime localNow) {
    if (!enabled) return false;
    final minuteOfDay = localNow.hour * 60 + localNow.minute;
    if (startMinute == endMinute) {
      // Zero-width window is a degenerate "always quiet" configuration
      // rather than "never quiet" — an explicit choice, not reachable
      // through the settings UI's own start/end pickers, but handled
      // predictably rather than left to whichever branch below happened
      // to match.
      return true;
    }
    if (startMinute < endMinute) {
      return minuteOfDay >= startMinute && minuteOfDay < endMinute;
    }
    return minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  /// [candidate] unchanged if it doesn't fall inside quiet hours;
  /// otherwise the next local instant quiet hours end (Roadmap Item 17
  /// section 9) — same calendar day if `endMinute` hasn't passed yet on
  /// [candidate]'s own day, otherwise the following day. Pure and
  /// deterministic like [isQuietAt]; callers own actually scheduling
  /// the returned instant.
  DateTime nextEligibleTime(DateTime candidate) {
    if (!isQuietAt(candidate)) return candidate;
    final endOfCandidateDay = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
    ).add(Duration(minutes: endMinute));
    if (endOfCandidateDay.isAfter(candidate)) return endOfCandidateDay;
    return endOfCandidateDay.add(const Duration(days: 1));
  }
}
