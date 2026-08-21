import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/idempotency_key_generator.dart';
import 'package:forge/core/backend/request_id_generator.dart';
import 'package:forge/core/backend/server_clock.dart';

void main() {
  group('DeterministicIdempotencyKeyGenerator', () {
    const generator = DeterministicIdempotencyKeyGenerator();

    test('the same inputs always produce the same key (retry-stable)', () {
      final a = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'submit',
        sequence: 3,
      );
      final b = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'submit',
        sequence: 3,
      );
      expect(a, b);
    });

    test('different sequences produce different keys', () {
      final a = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'submit',
        sequence: 3,
      );
      final b = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'submit',
        sequence: 4,
      );
      expect(a, isNot(b));
    });

    test('different command types at the same sequence produce different '
        'keys', () {
      final a = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'submit',
        sequence: 3,
      );
      final b = generator.generate(
        missionInstanceId: 'm1',
        commandType: 'progress',
        sequence: 3,
      );
      expect(a, isNot(b));
    });
  });

  group('SequentialRequestIdGenerator', () {
    test('successive calls never repeat', () {
      final generator = SequentialRequestIdGenerator(
        clock: MockServerClock(DateTime.utc(2026, 8, 10)),
      );
      final ids = List.generate(20, (_) => generator.next());
      expect(ids.toSet(), hasLength(20));
    });
  });
}
