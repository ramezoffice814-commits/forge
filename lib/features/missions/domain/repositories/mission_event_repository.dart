import '../events/mission_event.dart';
import '../sync/pending_mission_event.dart';

class MissionEventAppendException implements Exception {
  const MissionEventAppendException(this.message);

  final String message;

  @override
  String toString() => 'MissionEventAppendException: $message';
}

class MissionEventDuplicateException implements Exception {
  const MissionEventDuplicateException(this.idempotencyKey);

  final String idempotencyKey;

  @override
  String toString() =>
      'MissionEventDuplicateException: idempotency key "$idempotencyKey" already applied';
}

/// The append-only local store of mission events — the local source of
/// truth for lifecycle/progress derivation. [append]/[appendBatch] are the
/// *only* place a sequence number is ever assigned; nothing upstream of
/// this repository is allowed to invent one.
abstract class MissionEventRepository {
  /// Assigns the event's sequence number, validates integrity (non-empty
  /// identifiers, occurredAt not before the stream's first event, no
  /// duplicate idempotency key), and appends it. Throws
  /// [MissionEventAppendException] or [MissionEventDuplicateException]
  /// rather than silently accepting a bad event.
  Future<MissionEvent> append(MissionEvent draft);

  /// All-or-nothing: every draft must belong to the same mission stream;
  /// if any draft is invalid or duplicate, none are appended.
  Future<List<MissionEvent>> appendBatch(List<MissionEvent> drafts);

  List<MissionEvent> eventsForMission(String missionInstanceId);

  List<MissionEvent> eventsForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
  });

  List<PendingMissionEvent> pendingSyncEvents();

  void markSyncQueued(List<MissionEvent> events);

  void markSyncConfirmed(List<String> eventIds);

  void markSyncFailed(
    List<String> eventIds, {
    required String errorCode,
    bool permanent = false,
  });

  /// Emits the mission's full event list whenever it changes — does *not*
  /// replay the current value to a new subscriber; callers should read
  /// [eventsForMission] once for the initial snapshot before subscribing.
  Stream<List<MissionEvent>> observeMissionEvents(String missionInstanceId);

  void dispose();
}
