import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/sync/domain/entities/sync_operation.dart';
import 'package:forge/features/sync/domain/entities/sync_queue.dart';
import 'package:forge/features/sync/domain/enums/sync_operation_status.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  SyncOperation<String> op({
    required String id,
    required String key,
    required int sequence,
    DateTime? queuedAt,
  }) {
    return SyncOperation<String>(
      operationId: id,
      idempotencyKey: key,
      sequence: sequence,
      payload: 'payload-$id',
      status: SyncOperationStatus.pending,
      queuedAt: queuedAt ?? now,
    );
  }

  test('enqueue returns true for a new operation, false for a duplicate '
      'idempotency key', () {
    final queue = SyncQueue<String>();
    expect(queue.enqueue(op(id: 'a', key: 'k1', sequence: 1)), isTrue);
    expect(queue.enqueue(op(id: 'b', key: 'k1', sequence: 1)), isFalse);
    expect(queue.all, hasLength(1));
  });

  test('pendingInOrder is ordered by sequence, not insertion order', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'c', key: 'k3', sequence: 3));
    queue.enqueue(op(id: 'a', key: 'k1', sequence: 1));
    queue.enqueue(op(id: 'b', key: 'k2', sequence: 2));

    expect(queue.pendingInOrder.map((o) => o.operationId).toList(), [
      'a',
      'b',
      'c',
    ]);
  });

  test('ties in sequence break deterministically by queuedAt then '
      'operationId', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'z', key: 'k1', sequence: 1, queuedAt: now));
    queue.enqueue(op(id: 'a', key: 'k2', sequence: 1, queuedAt: now));

    expect(queue.pendingInOrder.map((o) => o.operationId).toList(), ['a', 'z']);
  });

  test('markConfirmed removes an operation from pendingInOrder — a '
      'confirmed operation is never reprocessed', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'a', key: 'k1', sequence: 1));
    queue.markConfirmed('a');

    expect(queue.pendingInOrder, isEmpty);
    expect(queue.operationFor('a')?.status, SyncOperationStatus.confirmed);
  });

  test('markFailed returns an operation to pending — retry-safe, no '
      'silent data loss', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'a', key: 'k1', sequence: 1));
    queue.markSyncing('a');
    queue.markFailed('a');

    expect(queue.operationFor('a')?.status, SyncOperationStatus.pending);
    expect(queue.pendingInOrder.map((o) => o.operationId), contains('a'));
  });

  test('markSyncing increments the attempt count on every call', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'a', key: 'k1', sequence: 1));
    queue.markSyncing('a');
    queue.markFailed('a');
    queue.markSyncing('a');

    expect(queue.operationFor('a')?.attemptCount, 2);
  });

  test('markConflict removes an operation from pendingInOrder pending a '
      'manual decision', () {
    final queue = SyncQueue<String>();
    queue.enqueue(op(id: 'a', key: 'k1', sequence: 1));
    queue.markConflict('a');

    expect(queue.pendingInOrder, isEmpty);
    expect(queue.operationFor('a')?.status, SyncOperationStatus.conflict);
  });

  test('updating an unknown operationId is a safe no-op', () {
    final queue = SyncQueue<String>();
    expect(() => queue.markConfirmed('does-not-exist'), returnsNormally);
  });
}
