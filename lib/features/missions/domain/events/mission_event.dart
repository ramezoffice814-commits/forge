import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import '../enums/rejection_reason.dart';
import '../progress/mission_progress_state.dart';
import 'mission_event_source.dart';

/// One immutable fact about a mission's history. Every subtype carries the
/// full set of integrity fields (section 5 of the spec) plus its own
/// narrowly-typed payload — never an unrestricted `Map<String, dynamic>`.
///
/// [sequenceNumber] is deliberately not settable by callers in practice:
/// use cases construct an event with `sequenceNumber: 0` (a placeholder)
/// and [MissionEventRepository.append] is the only code that calls
/// [withSequenceNumber] to assign the real, stream-ordered value.
@immutable
sealed class MissionEvent {
  const MissionEvent({
    required this.eventId,
    required this.missionInstanceId,
    required this.userId,
    required this.occurredAt,
    required this.clientCreatedAt,
    required this.sequenceNumber,
    required this.source,
    required this.idempotencyKey,
    this.schemaVersion = 1,
    this.clientSessionId,
  });

  final String eventId;
  final String missionInstanceId;
  final String userId;
  final DateTime occurredAt;
  final DateTime clientCreatedAt;
  final int sequenceNumber;
  final MissionEventSource source;
  final int schemaVersion;
  final String? clientSessionId;
  final String idempotencyKey;

  MissionEventType get type;

  MissionEvent withSequenceNumber(int sequenceNumber);
}

final class MissionAssigned extends MissionEvent {
  const MissionAssigned({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.assigned;

  @override
  MissionAssigned withSequenceNumber(int sequenceNumber) => MissionAssigned(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionViewed extends MissionEvent {
  const MissionViewed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.viewed;

  @override
  MissionViewed withSequenceNumber(int sequenceNumber) => MissionViewed(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionAccepted extends MissionEvent {
  const MissionAccepted({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.accepted;

  @override
  MissionAccepted withSequenceNumber(int sequenceNumber) => MissionAccepted(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionStarted extends MissionEvent {
  const MissionStarted({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.sessionId,
    super.schemaVersion,
    super.clientSessionId,
  });

  final String sessionId;

  @override
  MissionEventType get type => MissionEventType.started;

  @override
  MissionStarted withSequenceNumber(int sequenceNumber) => MissionStarted(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    sessionId: sessionId,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionProgressUpdated extends MissionEvent {
  const MissionProgressUpdated({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.progress,
    this.isCorrection = false,
    super.schemaVersion,
    super.clientSessionId,
  });

  /// The full new progress snapshot after this update (not a delta) — the
  /// reducer just takes the latest one, which keeps rehydration simple and
  /// naturally idempotent-safe for replays.
  final MissionProgressState progress;
  final bool isCorrection;

  @override
  MissionEventType get type => MissionEventType.progressUpdated;

  @override
  MissionProgressUpdated withSequenceNumber(int sequenceNumber) =>
      MissionProgressUpdated(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        progress: progress,
        isCorrection: isCorrection,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionPaused extends MissionEvent {
  const MissionPaused({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.paused;

  @override
  MissionPaused withSequenceNumber(int sequenceNumber) => MissionPaused(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionResumed extends MissionEvent {
  const MissionResumed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.resumed;

  @override
  MissionResumed withSequenceNumber(int sequenceNumber) => MissionResumed(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionSubmitted extends MissionEvent {
  const MissionSubmitted({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.submitted;

  @override
  MissionSubmitted withSequenceNumber(int sequenceNumber) => MissionSubmitted(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionValidationPassed extends MissionEvent {
  const MissionValidationPassed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.validationPassed;

  @override
  MissionValidationPassed withSequenceNumber(int sequenceNumber) =>
      MissionValidationPassed(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionValidationFailed extends MissionEvent {
  const MissionValidationFailed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.reasonCodes,
    this.userFacingExplanation,
    super.schemaVersion,
    super.clientSessionId,
  });

  final List<String> reasonCodes;
  final String? userFacingExplanation;

  @override
  MissionEventType get type => MissionEventType.validationFailed;

  @override
  MissionValidationFailed withSequenceNumber(int sequenceNumber) =>
      MissionValidationFailed(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        reasonCodes: reasonCodes,
        userFacingExplanation: userFacingExplanation,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionCompleted extends MissionEvent {
  const MissionCompleted({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.completed;

  @override
  MissionCompleted withSequenceNumber(int sequenceNumber) => MissionCompleted(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionCompletionUndone extends MissionEvent {
  const MissionCompletionUndone({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    this.reason,
    super.schemaVersion,
    super.clientSessionId,
  });

  final String? reason;

  @override
  MissionEventType get type => MissionEventType.completionUndone;

  @override
  MissionCompletionUndone withSequenceNumber(int sequenceNumber) =>
      MissionCompletionUndone(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        reason: reason,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionRejected extends MissionEvent {
  const MissionRejected({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.reason,
    this.replacementMissionInstanceId,
    super.schemaVersion,
    super.clientSessionId,
  });

  final RejectionReason reason;

  /// Known at append time (the replacement is selected *before* this event
  /// is appended) — events never need to be edited after the fact to link
  /// them together.
  final String? replacementMissionInstanceId;

  @override
  MissionEventType get type => MissionEventType.rejected;

  @override
  MissionRejected withSequenceNumber(int sequenceNumber) => MissionRejected(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    reason: reason,
    replacementMissionInstanceId: replacementMissionInstanceId,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionEasierRequested extends MissionEvent {
  const MissionEasierRequested({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.easierRequested;

  @override
  MissionEasierRequested withSequenceNumber(int sequenceNumber) =>
      MissionEasierRequested(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionCategoryChangeRequested extends MissionEvent {
  const MissionCategoryChangeRequested({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.requestedCategory,
    super.schemaVersion,
    super.clientSessionId,
  });

  final MissionCategory requestedCategory;

  @override
  MissionEventType get type => MissionEventType.categoryChangeRequested;

  @override
  MissionCategoryChangeRequested withSequenceNumber(int sequenceNumber) =>
      MissionCategoryChangeRequested(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        requestedCategory: requestedCategory,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionAbandoned extends MissionEvent {
  const MissionAbandoned({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    this.reason,
    super.schemaVersion,
    super.clientSessionId,
  });

  final String? reason;

  @override
  MissionEventType get type => MissionEventType.abandoned;

  @override
  MissionAbandoned withSequenceNumber(int sequenceNumber) => MissionAbandoned(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    reason: reason,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionExpired extends MissionEvent {
  const MissionExpired({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.expired;

  @override
  MissionExpired withSequenceNumber(int sequenceNumber) => MissionExpired(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionSyncQueued extends MissionEvent {
  const MissionSyncQueued({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.syncQueued;

  @override
  MissionSyncQueued withSequenceNumber(int sequenceNumber) => MissionSyncQueued(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}

final class MissionSyncConfirmed extends MissionEvent {
  const MissionSyncConfirmed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    super.schemaVersion,
    super.clientSessionId,
  });

  @override
  MissionEventType get type => MissionEventType.syncConfirmed;

  @override
  MissionSyncConfirmed withSequenceNumber(int sequenceNumber) =>
      MissionSyncConfirmed(
        eventId: eventId,
        missionInstanceId: missionInstanceId,
        userId: userId,
        occurredAt: occurredAt,
        clientCreatedAt: clientCreatedAt,
        sequenceNumber: sequenceNumber,
        source: source,
        idempotencyKey: idempotencyKey,
        schemaVersion: schemaVersion,
        clientSessionId: clientSessionId,
      );
}

final class MissionSyncFailed extends MissionEvent {
  const MissionSyncFailed({
    required super.eventId,
    required super.missionInstanceId,
    required super.userId,
    required super.occurredAt,
    required super.clientCreatedAt,
    required super.sequenceNumber,
    required super.source,
    required super.idempotencyKey,
    required this.errorCode,
    super.schemaVersion,
    super.clientSessionId,
  });

  final String errorCode;

  @override
  MissionEventType get type => MissionEventType.syncFailed;

  @override
  MissionSyncFailed withSequenceNumber(int sequenceNumber) => MissionSyncFailed(
    eventId: eventId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    occurredAt: occurredAt,
    clientCreatedAt: clientCreatedAt,
    sequenceNumber: sequenceNumber,
    source: source,
    idempotencyKey: idempotencyKey,
    errorCode: errorCode,
    schemaVersion: schemaVersion,
    clientSessionId: clientSessionId,
  );
}
