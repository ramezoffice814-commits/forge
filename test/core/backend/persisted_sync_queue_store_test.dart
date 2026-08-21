import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/commands/accept_mission_command.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';
import 'package:forge/core/backend/persisted_sync_queue_store.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/sync/domain/entities/sync_operation.dart';
import 'package:forge/features/sync/domain/enums/sync_operation_status.dart';

class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  final now = DateTime.utc(2026, 8, 19, 12);

  test('round-trips an accept command through save/load', () async {
    final fake = FakeSecureKeyValueStore();
    final store = PersistedSyncQueueStore(fake);

    final command = AcceptMissionCommand(
      commandId: 'cmd-1',
      missionInstanceId: 'mission-1',
      userId: 'user-a',
      timestamp: now,
      sequence: 1,
      idempotencyKey: 'key-1',
    );
    final operation = SyncOperation(
      operationId: 'cmd-1',
      idempotencyKey: 'key-1',
      sequence: 1,
      payload: command,
      status: SyncOperationStatus.pending,
      queuedAt: now,
    );

    await store.save('user-a', [operation]);
    final loaded = await store.load('user-a');

    expect(loaded, hasLength(1));
    expect(loaded.single.payload, isA<AcceptMissionCommand>());
    expect(loaded.single.payload.missionInstanceId, 'mission-1');
    expect(loaded.single.idempotencyKey, 'key-1');
  });

  test(
    'round-trips a submit command including its completion payload',
    () async {
      final fake = FakeSecureKeyValueStore();
      final store = PersistedSyncQueueStore(fake);

      final command = SubmitMissionCommand(
        commandId: 'cmd-3',
        missionInstanceId: 'mission-1',
        userId: 'user-a',
        timestamp: now,
        sequence: 3,
        idempotencyKey: 'key-3',
        completionPayload: {
          'progressType': 'binary',
          'progress': {'completed': true},
        },
      );
      final operation = SyncOperation(
        operationId: 'cmd-3',
        idempotencyKey: 'key-3',
        sequence: 3,
        payload: command,
        status: SyncOperationStatus.pending,
        queuedAt: now,
      );

      await store.save('user-a', [operation]);
      final loaded = await store.load('user-a');

      final restored = loaded.single.payload as SubmitMissionCommand;
      expect(restored.completionPayload['progressType'], 'binary');
    },
  );

  test('an empty/missing key loads as an empty list, not an error', () async {
    final store = PersistedSyncQueueStore(FakeSecureKeyValueStore());
    expect(await store.load('nobody'), isEmpty);
  });

  test(
    'corrupt persisted data loads as an empty list rather than crashing',
    () async {
      final fake = FakeSecureKeyValueStore();
      await fake.write('forge.sync_queue.user-a', 'not valid json{{{');
      final store = PersistedSyncQueueStore(fake);

      expect(await store.load('user-a'), isEmpty);
    },
  );

  group('account-switch isolation', () {
    test("User B's load never sees User A's persisted queue", () async {
      final fake = FakeSecureKeyValueStore();
      final store = PersistedSyncQueueStore(fake);

      final command = AcceptMissionCommand(
        commandId: 'cmd-a',
        missionInstanceId: 'mission-1',
        userId: 'user-a',
        timestamp: now,
        sequence: 1,
        idempotencyKey: 'key-a',
      );
      await store.save('user-a', [
        SyncOperation(
          operationId: 'cmd-a',
          idempotencyKey: 'key-a',
          sequence: 1,
          payload: command,
          status: SyncOperationStatus.pending,
          queuedAt: now,
        ),
      ]);

      expect(await store.load('user-b'), isEmpty);
      expect(await store.load('user-a'), hasLength(1));
    });

    test('clearing one user does not affect another', () async {
      final fake = FakeSecureKeyValueStore();
      final store = PersistedSyncQueueStore(fake);
      final command = AcceptMissionCommand(
        commandId: 'cmd-a',
        missionInstanceId: 'mission-1',
        userId: 'user-a',
        timestamp: now,
        sequence: 1,
        idempotencyKey: 'key-a',
      );
      final op = SyncOperation(
        operationId: 'cmd-a',
        idempotencyKey: 'key-a',
        sequence: 1,
        payload: command,
        status: SyncOperationStatus.pending,
        queuedAt: now,
      );
      await store.save('user-a', [op]);
      await store.save('user-b', [op]);

      await store.clear('user-a');

      expect(await store.load('user-a'), isEmpty);
      expect(await store.load('user-b'), hasLength(1));
    });
  });

  group('SyncQueueRestoreGuard', () {
    test(
      'drops a restored command whose own userId does not match the caller',
      () {
        final commandForA = AcceptMissionCommand(
          commandId: 'cmd-a',
          missionInstanceId: 'mission-1',
          userId: 'user-a',
          timestamp: now,
          sequence: 1,
          idempotencyKey: 'key-a',
        );
        final op = SyncOperation(
          operationId: 'cmd-a',
          idempotencyKey: 'key-a',
          sequence: 1,
          payload: commandForA,
          status: SyncOperationStatus.pending,
          queuedAt: now,
        );

        final restorableForA = SyncQueueRestoreGuard.restorable([op], 'user-a');
        final restorableForB = SyncQueueRestoreGuard.restorable([op], 'user-b');

        expect(restorableForA, hasLength(1));
        expect(restorableForB, isEmpty);
      },
    );
  });
}
