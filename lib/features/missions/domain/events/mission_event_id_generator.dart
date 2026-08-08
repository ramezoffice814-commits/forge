import 'dart:math';

/// Local-only id/idempotency-key generation — no backend allocates these
/// yet, so ids only need to be unique within this device's event log, not
/// globally unique. Deliberately avoids adding a `uuid` dependency for
/// something this simple.
abstract final class MissionEventIdGenerator {
  static final Random _random = Random();
  static int _counter = 0;

  static String newEventId() {
    _counter += 1;
    final entropy = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'evt-${DateTime.now().microsecondsSinceEpoch}-$_counter-$entropy';
  }

  static String newSessionId() {
    _counter += 1;
    final entropy = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'sess-${DateTime.now().microsecondsSinceEpoch}-$_counter-$entropy';
  }

  /// A fixed key for events that must only ever exist once per mission
  /// stream (assigned/viewed/accepted) — a second attempt to append one is
  /// a no-op duplicate, not a new fact, which is what stops e.g. a double
  /// tap from recording two acceptances.
  static String singleton(String missionInstanceId, String label) =>
      '$missionInstanceId:$label';
}
