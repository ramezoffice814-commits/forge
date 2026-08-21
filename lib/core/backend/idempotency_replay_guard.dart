/// What a guard decided about one incoming command.
enum CommandAcceptance {
  /// A genuinely new command for this mission — safe to process.
  accepted,

  /// The exact same [idempotencyKey] was already processed — the caller
  /// must return the previously-cached result, never reprocess.
  duplicateRetry,

  /// This [sequence] is at or below the mission's last accepted sequence,
  /// under a *different* idempotency key — a replay attempt, not a
  /// legitimate retry. Must be rejected.
  staleSequence,

  /// This [sequence] skips ahead of the mission's expected next sequence
  /// — the client is missing an intermediate command. Must be rejected
  /// until the gap is filled.
  outOfOrder,
}

/// Domain-safe idempotency/replay protection — no network, no storage,
/// pure in-memory bookkeeping any [BackendClient] adapter (mock now, a
/// real one later) can delegate to. One instance tracks every command
/// type for a mission against a single monotonic sequence, matching
/// "monotonically increasing mission sequence/version" (spec section 5) —
/// accept/start/progress/submit all share one counter per mission, not
/// one each.
class IdempotencyReplayGuard {
  final Map<String, Object?> _cachedResults = {};
  final Map<String, int> _lastAcceptedSequenceByMission = {};

  CommandAcceptance evaluate({
    required String missionInstanceId,
    required String idempotencyKey,
    required int sequence,
  }) {
    if (_cachedResults.containsKey(idempotencyKey)) {
      return CommandAcceptance.duplicateRetry;
    }

    final lastAccepted = _lastAcceptedSequenceByMission[missionInstanceId] ?? 0;
    if (sequence <= lastAccepted) {
      return CommandAcceptance.staleSequence;
    }
    if (sequence > lastAccepted + 1) {
      return CommandAcceptance.outOfOrder;
    }
    return CommandAcceptance.accepted;
  }

  Object? cachedResultFor(String idempotencyKey) =>
      _cachedResults[idempotencyKey];

  /// Must only be called after [evaluate] returned
  /// [CommandAcceptance.accepted] — records [result] under
  /// [idempotencyKey] (so a later retry finds it) and advances the
  /// mission's sequence.
  void recordAccepted({
    required String missionInstanceId,
    required String idempotencyKey,
    required int sequence,
    required Object? result,
  }) {
    _cachedResults[idempotencyKey] = result;
    _lastAcceptedSequenceByMission[missionInstanceId] = sequence;
  }

  int lastAcceptedSequenceFor(String missionInstanceId) =>
      _lastAcceptedSequenceByMission[missionInstanceId] ?? 0;
}
