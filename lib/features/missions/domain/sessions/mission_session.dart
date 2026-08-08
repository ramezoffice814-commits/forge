import 'package:flutter/foundation.dart';

import '../events/mission_event_source.dart';

/// One logical work session on a mission. Pause/resume don't start a new
/// session — they open/close active *intervals* within the same one (see
/// `MissionSessionReducer`); a new [MissionSession] only begins at the next
/// `MissionStarted` (e.g. after a completion is undone).
@immutable
class MissionSession {
  const MissionSession({
    required this.sessionId,
    required this.missionInstanceId,
    required this.startedAt,
    required this.activeDuration,
    required this.pauseCount,
    required this.interruptionCount,
    required this.source,
    this.pausedAt,
    this.endedAt,
    this.clientSessionId,
  });

  final String sessionId;
  final String missionInstanceId;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;

  /// Neutral, factual — never a "focus quality" claim (see spec section
  /// 10's explicit warning against inferring quality from time alone).
  final Duration activeDuration;
  final int pauseCount;
  final int interruptionCount;
  final MissionEventSource source;
  final String? clientSessionId;

  bool get isOpen => endedAt == null;
  bool get isPaused => pausedAt != null && endedAt == null;

  MissionSession copyWith({
    Object? pausedAt = _unset,
    DateTime? endedAt,
    Duration? activeDuration,
    int? pauseCount,
    int? interruptionCount,
  }) {
    return MissionSession(
      sessionId: sessionId,
      missionInstanceId: missionInstanceId,
      startedAt: startedAt,
      pausedAt: identical(pausedAt, _unset)
          ? this.pausedAt
          : pausedAt as DateTime?,
      endedAt: endedAt ?? this.endedAt,
      activeDuration: activeDuration ?? this.activeDuration,
      pauseCount: pauseCount ?? this.pauseCount,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      source: source,
      clientSessionId: clientSessionId,
    );
  }
}

const _unset = Object();
