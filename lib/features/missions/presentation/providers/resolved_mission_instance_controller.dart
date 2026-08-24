import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../data/cached_mission_assignment_store.dart';
import '../../domain/entities/mission_instance.dart';
import '../../domain/entities/resolved_mission_instance.dart';
import '../../domain/enums/mission_instance_authority.dart';
import 'mission_instance_provider.dart';
import 'mission_providers.dart';
import 'mission_selection_controller.dart';
import 'mission_selection_state.dart';

/// Roadmap Item 13C: the one provider Dashboard, Daily Transmission,
/// ActiveMissionPage's route id, and every backend mission command must
/// resolve today's mission through. In mock mode this is a thin,
/// same-tick wrapper over [missionInstanceProvider] (unchanged behavior).
/// In live/staging mode it additionally requests the server's
/// authoritative daily assignment and adopts its `missionInstanceId` —
/// [missionInstanceProvider]'s own locally-generated id is never sent to
/// the backend once this resolves to [MissionInstanceAuthority.serverConfirmed].
@immutable
sealed class ResolvedMissionInstanceState {
  const ResolvedMissionInstanceState();
}

class ResolvedMissionInstanceLoading extends ResolvedMissionInstanceState {
  const ResolvedMissionInstanceLoading();
}

@immutable
class ResolvedMissionInstanceReady extends ResolvedMissionInstanceState {
  const ResolvedMissionInstanceReady(this.resolved);

  /// `null` only when mission selection itself has no mission to offer
  /// (error/empty state) — mirrors `missionInstanceProvider`'s own
  /// nullability rather than inventing a new "no mission" representation.
  final ResolvedMissionInstance? resolved;
}

class ResolvedMissionInstanceController
    extends Notifier<ResolvedMissionInstanceState> {
  final Completer<void> _readyCompleter = Completer<void>();

  /// Set by `ref.onDispose` — this provider's `Ref` doesn't expose a
  /// `mounted` getter in the Riverpod version this project pins, so this
  /// flag is the manual equivalent (same shape as
  /// `DailyTransmissionController`'s `_generation`/`_stale` pattern
  /// elsewhere in this codebase): a short-lived test `ProviderContainer`
  /// can dispose while `_resolve` is mid-await, and reading/writing
  /// through a disposed `ref` throws.
  bool _disposed = false;

  /// Resolves once the first resolution (mock passthrough, or a live
  /// assignment attempt — success, cache fallback, or provisional
  /// fallback) has landed. Callers that need the authoritative id before
  /// sending a backend command (`DailyTransmissionController.acceptMission`)
  /// await this exactly like `MissionSelectionController.ready`.
  Future<void> get ready => _readyCompleter.future;

  @override
  ResolvedMissionInstanceState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_resolve);
    return const ResolvedMissionInstanceLoading();
  }

  void _complete() {
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  Future<void> _resolve() async {
    await ref.read(missionSelectionControllerProvider.notifier).ready;
    if (_disposed) return;
    final selectionState = ref.read(missionSelectionControllerProvider);
    final localInstance = ref.read(missionInstanceProvider);

    if (selectionState is! MissionSelectionReady || localInstance == null) {
      state = const ResolvedMissionInstanceReady(null);
      _complete();
      return;
    }

    final mode = ref.read(backendModeProvider);
    if (mode == BackendMode.mock) {
      state = ResolvedMissionInstanceReady(
        ResolvedMissionInstance(
          instance: localInstance,
          authority: MissionInstanceAuthority.localOnly,
        ),
      );
      _complete();
      return;
    }

    final userId = ref.read(currentBackendUserIdProvider);
    final assignmentClient = ref.read(missionAssignmentClientProvider);
    if (userId == null || assignmentClient == null) {
      state = ResolvedMissionInstanceReady(
        ResolvedMissionInstance(
          instance: localInstance,
          authority: MissionInstanceAuthority.provisionalPendingServer,
        ),
      );
      _complete();
      return;
    }

    final dateKey =
        '${localInstance.assignedDate.year.toString().padLeft(4, '0')}-'
        '${localInstance.assignedDate.month.toString().padLeft(2, '0')}-'
        '${localInstance.assignedDate.day.toString().padLeft(2, '0')}';

    try {
      final result = await assignmentClient.assignDailyMission(
        commandId: 'assign-req-${DateTime.now().microsecondsSinceEpoch}',
        idempotencyKey: 'assign:$userId:$dateKey',
        requestedMissionDefinitionId: selectionState.result.selectedMission.id,
      );
      if (_disposed) return;

      await ref
          .read(cachedMissionAssignmentStoreProvider)
          .save(
            userId,
            CachedMissionAssignment(
              missionInstanceId: result.missionInstanceId,
              missionDefinitionId: result.missionDefinitionId,
              assignedDate: result.assignedDate,
            ),
          );
      if (_disposed) return;

      final reconciled =
          result.missionDefinitionId !=
          selectionState.result.selectedMission.id;

      if (!reconciled) {
        state = ResolvedMissionInstanceReady(
          ResolvedMissionInstance(
            instance: MissionInstance.fromSelectionResult(
              selectionState.result,
              instanceId: result.missionInstanceId,
              assignedDate: result.assignedDate,
            ),
            authority: MissionInstanceAuthority.serverConfirmed,
          ),
        );
        _complete();
        return;
      }

      // Outcome B (spec section 9): the server's daily assignment is for
      // a different mission than the one locally requested — never build
      // the display instance from the (wrong) local selection result.
      final catalog = await ref
          .read(missionCatalogRepositoryProvider)
          .getCatalog();
      if (_disposed) return;
      final serverDefinition = catalog
          .where((d) => d.id == result.missionDefinitionId)
          .firstOrNull;

      state = ResolvedMissionInstanceReady(
        serverDefinition == null
            ? ResolvedMissionInstance(
                instance: localInstance,
                authority: MissionInstanceAuthority.provisionalPendingServer,
              )
            : ResolvedMissionInstance(
                instance: MissionInstance.fromDefinition(
                  serverDefinition,
                  instanceId: result.missionInstanceId,
                  assignedDate: result.assignedDate,
                  resolvedDifficulty: serverDefinition.baseDifficulty,
                  resolvedDuration: serverDefinition.estimatedMinutes,
                ),
                authority: MissionInstanceAuthority.serverConfirmed,
                reconciledToDifferentMission: true,
              ),
      );
      _complete();
    } catch (_) {
      // Offline, or the server call failed some other way — fall back to
      // a cached confirmed assignment if one exists for today; only then
      // fall back further to the local provisional instance (spec
      // section 8).
      final cached = await ref
          .read(cachedMissionAssignmentStoreProvider)
          .load(userId, localInstance.assignedDate);
      if (_disposed) return;

      if (cached != null &&
          cached.missionDefinitionId ==
              selectionState.result.selectedMission.id) {
        state = ResolvedMissionInstanceReady(
          ResolvedMissionInstance(
            instance: MissionInstance.fromSelectionResult(
              selectionState.result,
              instanceId: cached.missionInstanceId,
              assignedDate: cached.assignedDate,
            ),
            authority: MissionInstanceAuthority.serverConfirmed,
          ),
        );
        _complete();
        return;
      }

      state = ResolvedMissionInstanceReady(
        ResolvedMissionInstance(
          instance: localInstance,
          authority: MissionInstanceAuthority.provisionalPendingServer,
        ),
      );
      _complete();
    }
  }
}

final resolvedMissionInstanceControllerProvider =
    NotifierProvider<
      ResolvedMissionInstanceController,
      ResolvedMissionInstanceState
    >(ResolvedMissionInstanceController.new);

/// Derived, synchronous read — mirrors how `missionInstanceProvider` is
/// consumed today, so existing synchronous call sites (Dashboard's
/// repository provider) need only swap which provider they watch, not how
/// they watch it. `null` while loading or on error/empty, exactly like
/// `missionInstanceProvider`.
final resolvedMissionInstanceProvider = Provider<ResolvedMissionInstance?>((
  ref,
) {
  final state = ref.watch(resolvedMissionInstanceControllerProvider);
  return state is ResolvedMissionInstanceReady ? state.resolved : null;
});
