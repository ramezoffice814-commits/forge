import 'dart:async';

import '../../domain/events/mission_event.dart';
import '../../domain/repositories/mission_event_repository.dart';
import '../../domain/sync/mission_sync_status.dart';
import '../../domain/sync/pending_mission_event.dart';

/// In-memory implementation — the only one this phase ships (spec section
/// 16: don't add a native persistence dependency just to satisfy this
/// phase). A persisted adapter (e.g. wrapping the existing secure
/// key-value store, or a proper embedded database once the native-build
/// blocker mentioned elsewhere in this project is resolved) is a
/// straightforward next step behind this same interface — nothing above
/// this class needs to change to add one.
class InMemoryMissionEventRepository implements MissionEventRepository {
  final Map<String, List<MissionEvent>> _byMission = {};
  final Map<String, Set<String>> _idempotencyKeysByMission = {};
  final Map<String, PendingMissionEvent> _pendingByEventId = {};
  final Map<String, StreamController<List<MissionEvent>>> _controllers = {};

  @override
  Future<MissionEvent> append(MissionEvent draft) async {
    final assigned = _validateAndAssign(draft);
    _byMission.putIfAbsent(draft.missionInstanceId, () => []).add(assigned);
    _idempotencyKeysByMission
        .putIfAbsent(draft.missionInstanceId, () => {})
        .add(draft.idempotencyKey);
    _emit(draft.missionInstanceId);
    return assigned;
  }

  @override
  Future<List<MissionEvent>> appendBatch(List<MissionEvent> drafts) async {
    if (drafts.isEmpty) return const [];
    final missionId = drafts.first.missionInstanceId;
    if (drafts.any((d) => d.missionInstanceId != missionId)) {
      throw const MissionEventAppendException(
        'appendBatch requires every draft to belong to the same mission stream.',
      );
    }

    final existing = _byMission[missionId] ?? const [];
    final existingKeys = Set<String>.of(
      _idempotencyKeysByMission[missionId] ?? {},
    );
    var seq = existing.length;
    final assigned = <MissionEvent>[];

    for (final draft in drafts) {
      _validateShape(draft, existing);
      if (existingKeys.contains(draft.idempotencyKey)) {
        throw MissionEventDuplicateException(draft.idempotencyKey);
      }
      existingKeys.add(draft.idempotencyKey);
      seq += 1;
      assigned.add(draft.withSequenceNumber(seq));
    }

    // Nothing is committed until every draft in the batch has validated —
    // this is what keeps a batch atomic (no half-applied completion state).
    _byMission.putIfAbsent(missionId, () => []).addAll(assigned);
    _idempotencyKeysByMission[missionId] = existingKeys;
    _emit(missionId);
    return assigned;
  }

  MissionEvent _validateAndAssign(MissionEvent draft) {
    final existing = _byMission[draft.missionInstanceId] ?? const [];
    _validateShape(draft, existing);

    final existingKeys =
        _idempotencyKeysByMission[draft.missionInstanceId] ?? const {};
    if (existingKeys.contains(draft.idempotencyKey)) {
      throw MissionEventDuplicateException(draft.idempotencyKey);
    }

    return draft.withSequenceNumber(existing.length + 1);
  }

  void _validateShape(
    MissionEvent draft,
    List<MissionEvent> existingForMission,
  ) {
    if (draft.eventId.isEmpty ||
        draft.missionInstanceId.isEmpty ||
        draft.userId.isEmpty ||
        draft.idempotencyKey.isEmpty) {
      throw const MissionEventAppendException(
        'Malformed event: missing a required identifier.',
      );
    }
    if (existingForMission.isNotEmpty &&
        draft.occurredAt.isBefore(existingForMission.first.occurredAt)) {
      throw const MissionEventAppendException(
        "Event occurredAt precedes the mission's assignment time.",
      );
    }
  }

  @override
  List<MissionEvent> eventsForMission(String missionInstanceId) {
    return List.unmodifiable(_byMission[missionInstanceId] ?? const []);
  }

  @override
  List<MissionEvent> eventsForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  }) {
    final all =
        _byMission.values
            .expand((events) => events)
            .where((e) => e.userId == userId)
            .where((e) => from == null || !e.occurredAt.isBefore(from))
            .where((e) => to == null || !e.occurredAt.isAfter(to))
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return List.unmodifiable(all);
  }

  @override
  Stream<List<MissionEvent>> observeMissionEvents(String missionInstanceId) {
    final controller = _controllers.putIfAbsent(
      missionInstanceId,
      () => StreamController<List<MissionEvent>>.broadcast(),
    );
    return controller.stream;
  }

  void _emit(String missionInstanceId) {
    _controllers[missionInstanceId]?.add(eventsForMission(missionInstanceId));
  }

  @override
  List<PendingMissionEvent> pendingSyncEvents() {
    return _pendingByEventId.values.where((p) => !p.isTerminal).toList();
  }

  @override
  void markSyncQueued(List<MissionEvent> events) {
    for (final event in events) {
      // No duplicate queue entries: re-queuing an already-tracked event
      // just leaves its existing attempt history alone.
      _pendingByEventId.putIfAbsent(
        event.eventId,
        () => PendingMissionEvent(
          localEventId: event.eventId,
          missionInstanceId: event.missionInstanceId,
          idempotencyKey: event.idempotencyKey,
          sequenceNumber: event.sequenceNumber,
          queuedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  @override
  void markSyncConfirmed(List<String> eventIds) {
    for (final id in eventIds) {
      final pending = _pendingByEventId[id];
      if (pending == null) continue;
      _pendingByEventId[id] = pending.copyWith(
        syncStatus: MissionSyncStatus.confirmed,
        lastAttemptAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  void markSyncFailed(
    List<String> eventIds, {
    required String errorCode,
    bool permanent = false,
  }) {
    for (final id in eventIds) {
      final pending = _pendingByEventId[id];
      if (pending == null) continue;
      _pendingByEventId[id] = pending.copyWith(
        syncStatus: permanent
            ? MissionSyncStatus.permanentFailure
            : MissionSyncStatus.retryableFailure,
        attemptCount: pending.attemptCount + 1,
        lastAttemptAt: DateTime.now().toUtc(),
        lastErrorCode: errorCode,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
