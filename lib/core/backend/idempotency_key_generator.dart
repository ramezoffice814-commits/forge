/// Produces the key that identifies "this exact logical operation,"
/// stable across retries. Two calls with the same inputs must always
/// produce the same key — that stability is what lets
/// [IdempotencyReplayGuard] recognize a legitimate retry versus a new
/// command.
abstract class IdempotencyKeyGenerator {
  String generate({
    required String missionInstanceId,
    required String commandType,
    required int sequence,
  });
}

/// Purely a deterministic string join — no randomness, no clock
/// dependency, so the same logical command always yields the same key no
/// matter how many times (or how long after) it's retried.
class DeterministicIdempotencyKeyGenerator implements IdempotencyKeyGenerator {
  const DeterministicIdempotencyKeyGenerator();

  @override
  String generate({
    required String missionInstanceId,
    required String commandType,
    required int sequence,
  }) {
    return '$missionInstanceId:$commandType:$sequence';
  }
}
