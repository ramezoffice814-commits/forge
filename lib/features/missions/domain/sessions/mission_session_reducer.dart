import '../events/mission_event.dart';
import 'mission_session.dart';

class MissionSessionReduction {
  const MissionSessionReduction({
    required this.sessionHistory,
    required this.currentSession,
    required this.totalActiveDuration,
    required this.totalPausedDuration,
  });

  final List<MissionSession> sessionHistory;

  /// Non-null only while a session is genuinely open (active or paused,
  /// not yet closed by submit/complete/abandon).
  final MissionSession? currentSession;
  final Duration totalActiveDuration;
  final Duration totalPausedDuration;
}

/// Derives session/duration facts purely from ordered events — never from
/// wall-clock subtraction at read time, so the same event stream always
/// yields the same durations regardless of when it's replayed.
abstract final class MissionSessionReducer {
  /// A single unverified interval (active or paused) longer than this is
  /// treated as a clock anomaly and capped, rather than trusted outright —
  /// e.g. a device asleep for a day should not silently count as one active
  /// day of work.
  static const _maxTrustedIntervalDuration = Duration(hours: 3);

  static MissionSessionReduction reduce(List<MissionEvent> orderedEvents) {
    final closed = <MissionSession>[];
    MissionSession? current;
    DateTime? activeIntervalStart;
    DateTime? pauseIntervalStart;
    var totalActive = Duration.zero;
    var totalPaused = Duration.zero;

    Duration boundedDelta(DateTime start, DateTime end) {
      final delta = end.difference(start);
      if (delta.isNegative) return Duration.zero;
      return delta > _maxTrustedIntervalDuration
          ? _maxTrustedIntervalDuration
          : delta;
    }

    void closeCurrent(DateTime endedAt) {
      final session = current;
      if (session == null) return;
      closed.add(session.copyWith(endedAt: endedAt));
      current = null;
      activeIntervalStart = null;
      pauseIntervalStart = null;
    }

    for (final event in orderedEvents) {
      switch (event) {
        case MissionStarted():
          current = MissionSession(
            sessionId: event.sessionId,
            missionInstanceId: event.missionInstanceId,
            startedAt: event.occurredAt,
            activeDuration: Duration.zero,
            pauseCount: 0,
            interruptionCount: 0,
            source: event.source,
            clientSessionId: event.clientSessionId,
          );
          activeIntervalStart = event.occurredAt;

        case MissionPaused():
          final session = current;
          if (session != null && activeIntervalStart != null) {
            final delta = boundedDelta(activeIntervalStart!, event.occurredAt);
            totalActive += delta;
            current = session.copyWith(
              activeDuration: session.activeDuration + delta,
              pauseCount: session.pauseCount + 1,
              pausedAt: event.occurredAt,
            );
          }
          activeIntervalStart = null;
          pauseIntervalStart = event.occurredAt;

        case MissionResumed():
          if (pauseIntervalStart != null) {
            totalPaused += boundedDelta(pauseIntervalStart!, event.occurredAt);
          }
          pauseIntervalStart = null;
          activeIntervalStart = event.occurredAt;
          if (current != null) {
            current = current!.copyWith(pausedAt: null);
          }

        case MissionSubmitted():
        case MissionCompleted():
        case MissionAbandoned():
        case MissionExpired():
          final session = current;
          if (session != null && activeIntervalStart != null) {
            final delta = boundedDelta(activeIntervalStart!, event.occurredAt);
            totalActive += delta;
            current = session.copyWith(
              activeDuration: session.activeDuration + delta,
            );
          }
          closeCurrent(event.occurredAt);

        case MissionCompletionUndone():
          // The prior session stays closed/superseded; work resumes under
          // a new session at the next MissionStarted.
          break;

        default:
          break;
      }
    }

    return MissionSessionReduction(
      sessionHistory: closed,
      currentSession: current,
      totalActiveDuration: totalActive,
      totalPausedDuration: totalPaused,
    );
  }
}
