import 'dart:async';

import '../../features/sync/domain/enums/sync_operation_status.dart';
import 'persisted_sync_queue_store.dart';
import 'sync_queue_executor.dart';
import 'sync_queueing_backend_client.dart';

/// Coarse result of one startup sync attempt — a status, not a promise:
/// [degraded] covers "still offline", "hit a conflict", and "timed out"
/// alike, since the app's job at startup is only to enter a clean state,
/// never to keep retrying (spec section 8).
enum AppStartupSyncResult { noWorkToDo, synced, degraded }

/// Runs once at authenticated app startup (spec section 8): restore any
/// queued provisional commands this user had persisted from a previous
/// session, attempt one bounded sync pass, then stop — never an infinite
/// retry loop, never blocking the rest of the app indefinitely (the
/// [timeout] is the hard ceiling on that).
class AppStartupSyncCoordinator {
  const AppStartupSyncCoordinator(this._store, this._client, this._executor);

  final PersistedSyncQueueStore _store;
  final SyncQueueingBackendClient _client;
  final SyncQueueExecutor _executor;

  Future<AppStartupSyncResult> run({
    required String userId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final restored = await _store.load(userId);
    final owned = SyncQueueRestoreGuard.restorable(restored, userId);

    for (final operation in owned) {
      // A command persisted mid-flight (status `syncing`) when the app
      // was last killed is not actually in flight anymore — normalize it
      // back to `pending` so it's retried, not stuck forever. `confirmed`
      // operations have nothing left to do and are simply not restored.
      if (operation.status == SyncOperationStatus.confirmed) continue;
      final normalized = operation.status == SyncOperationStatus.syncing
          ? operation.copyWith(status: SyncOperationStatus.pending)
          : operation;
      _client.queue.enqueue(normalized);
    }

    if (_client.queue.pendingInOrder.isEmpty) {
      return AppStartupSyncResult.noWorkToDo;
    }

    try {
      final snapshot = await _executor.runOnce().timeout(timeout);
      await _store.save(userId, _client.queue.all);
      return snapshot.status == SyncExecutorStatus.idle
          ? AppStartupSyncResult.synced
          : AppStartupSyncResult.degraded;
    } on TimeoutException {
      await _store.save(userId, _client.queue.all);
      return AppStartupSyncResult.degraded;
    } catch (_) {
      // Backend unavailable in some other way — enter degraded/offline
      // state cleanly rather than propagate and block startup.
      return AppStartupSyncResult.degraded;
    }
  }
}
