import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../features/auth/presentation/auth_state_notifier.dart';
import '../../features/sync/domain/entities/sync_queue.dart';
import '../config/app_config.dart';
import '../storage/secure_key_value_store.dart';
import 'authenticated_backend_client.dart';
import 'backend_client.dart';
import 'backend_mode.dart';
import 'commands/backend_command.dart';
import 'edge_functions_client.dart';
import 'mission_assignment_client.dart';
import 'mock_backend_client.dart';
import 'persisted_sync_queue_store.dart';
import 'supabase_backend_client.dart';
import 'supabase_edge_functions_client.dart';
import 'supabase_mission_assignment_client.dart';
import 'sync_queue_executor.dart';
import 'sync_queueing_backend_client.dart';

/// The one place this app decides mock vs. live — every other backend
/// provider below derives from this, never re-reads [AppConfig] itself
/// (spec section 1/2: a single, clear runtime mode, never re-decided ad
/// hoc per screen).
final backendModeProvider = Provider<BackendMode>((ref) {
  return resolveBackendMode(
    isRelease: kReleaseMode,
    isMock: AppConfig.isMock,
    isSupabaseConfigured: AppConfig.isSupabaseConfigured,
    isAuthorizedBetaBuild: AppConfig.isPublicBetaBuild,
  );
});

/// Safe diagnostics snapshot — never a credential value, see
/// [BackendModeStatus]'s own doc comment.
final backendModeStatusProvider = Provider<BackendModeStatus>((ref) {
  return buildBackendModeStatus(ref.watch(backendModeProvider));
});

/// Only ever constructed when [backendModeProvider] resolves to
/// [BackendMode.liveSupabase] — `Supabase.instance.client` throws if
/// `Supabase.initialize` was never called, which `main.dart` only does
/// for live mode (see that file). [rawBackendClientProvider]'s `switch`
/// below is what guarantees this provider is never even evaluated in
/// mock mode, not a runtime check here.
final edgeFunctionsClientProvider = Provider<EdgeFunctionsClient>((ref) {
  return SupabaseEdgeFunctionsClient(supa.Supabase.instance.client);
});

/// The un-authenticated-identity-wrapped [BackendClient] — [MockBackendClient]
/// for mock mode, the real [SupabaseBackendClient] for live mode. Screens
/// never depend on this directly (spec section 2: "do not couple screens
/// directly to Supabase SDK types") — always go through
/// [backendClientProvider] instead, which adds identity + offline queueing.
final rawBackendClientProvider = Provider<BackendClient>((ref) {
  final mode = ref.watch(backendModeProvider);
  return switch (mode) {
    BackendMode.mock => MockBackendClient(),
    BackendMode.liveSupabase => SupabaseBackendClient(
      ref.watch(edgeFunctionsClientProvider),
    ),
  };
});

/// The authenticated user's id, or `null` when signed out — the single
/// source [authenticatedBackendClientProvider] and the sync-queue
/// partitioning providers below both read, so they can never disagree
/// about "who is the current user" (spec section 18's account-switch
/// safety starts here).
final currentBackendUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateNotifierProvider.select((s) => s.session?.user.id));
});

/// Refuses to forward a command for anyone but the actual signed-in user
/// — when signed out, wraps with a sentinel id no real command will ever
/// carry, so [AuthenticatedBackendClient]'s ownership check rejects
/// anything a caller mistakenly tries to send while unauthenticated,
/// rather than silently using a stale/wrong identity.
final authenticatedBackendClientProvider = Provider<BackendClient>((ref) {
  final userId =
      ref.watch(currentBackendUserIdProvider) ?? '__unauthenticated__';
  return AuthenticatedBackendClient(
    ref.watch(rawBackendClientProvider),
    userId,
  );
});

final syncQueueStoreProvider = Provider<PersistedSyncQueueStore>((ref) {
  return PersistedSyncQueueStore(ref.watch(secureKeyValueStoreProvider));
});

/// A fresh, empty, in-memory queue per provider-container lifetime.
/// Deliberately synchronous (a `Provider.build` must be) — restoring
/// persisted operations from [syncQueueStoreProvider] is
/// `AppStartupSyncCoordinator`'s explicit, awaited job, not something
/// hidden inside provider construction. Re-created whenever
/// [currentBackendUserIdProvider] changes (`ref.watch` below), so a
/// signed-out-then-different-user session never inherits the previous
/// user's in-memory queue — the other half of account-switch isolation,
/// alongside [PersistedSyncQueueStore]'s per-user storage key.
final missionSyncQueueProvider = Provider<SyncQueue<BackendCommand>>((ref) {
  ref.watch(currentBackendUserIdProvider);
  return SyncQueue<BackendCommand>();
});

final syncQueueingBackendClientProvider = Provider<SyncQueueingBackendClient>((
  ref,
) {
  return SyncQueueingBackendClient(
    ref.watch(authenticatedBackendClientProvider),
    ref.watch(missionSyncQueueProvider),
  );
});

final syncQueueExecutorProvider = Provider<SyncQueueExecutor>((ref) {
  return SyncQueueExecutor(ref.watch(syncQueueingBackendClientProvider));
});

/// The one provider mission flows should actually depend on — identity-
/// checked, offline-queueing, ordered. Everything above this line is
/// composition; this is the seam the rest of the app uses (spec section
/// 2's "Create Riverpod providers for: BackendClient,
/// AuthenticatedBackendClient, SyncQueueingBackendClient").
final backendClientProvider = Provider<SyncQueueingBackendClient>((ref) {
  return ref.watch(syncQueueingBackendClientProvider);
});

/// `null` in mock mode — mock mode never touches this at all (spec
/// section 5/8). Live mode gets the real client, built from the same
/// [edgeFunctionsClientProvider] the mission-command adapter uses.
final missionAssignmentClientProvider = Provider<MissionAssignmentClient?>((
  ref,
) {
  final mode = ref.watch(backendModeProvider);
  if (mode == BackendMode.mock) return null;
  return SupabaseMissionAssignmentClient(
    ref.watch(edgeFunctionsClientProvider),
  );
});
