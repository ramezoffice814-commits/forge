import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/backend_error_ux.dart';

void main() {
  group('mapBackendErrorToUx', () {
    test('stale_sequence maps to refresh/reconcile', () {
      expect(
        mapBackendErrorToUx('stale_sequence', 'x'),
        isA<RefreshAndReconcileUx>(),
      );
    });

    test('out_of_order maps to refresh/reconcile', () {
      expect(
        mapBackendErrorToUx('out_of_order', 'x'),
        isA<RefreshAndReconcileUx>(),
      );
    });

    test('idempotency_conflict maps to sync conflict', () {
      expect(
        mapBackendErrorToUx('idempotency_conflict', 'x'),
        isA<SyncConflictUx>(),
      );
    });

    test('invalid_transition maps to mission state changed', () {
      expect(
        mapBackendErrorToUx('invalid_transition', 'x'),
        isA<MissionStateChangedUx>(),
      );
    });

    test('mission_not_found maps to mission state changed', () {
      expect(
        mapBackendErrorToUx('mission_not_found', 'x'),
        isA<MissionStateChangedUx>(),
      );
    });

    test('unauthenticated maps to re-auth required', () {
      expect(
        mapBackendErrorToUx('unauthenticated', 'x'),
        isA<ReAuthRequiredUx>(),
      );
    });

    test('completion_requirements_not_met maps to keep mission open', () {
      expect(
        mapBackendErrorToUx('completion_requirements_not_met', 'x'),
        isA<KeepMissionOpenUx>(),
      );
    });

    test('internal_error maps to a retry-safe generic state', () {
      expect(
        mapBackendErrorToUx('internal_error', 'x'),
        isA<RetrySafeGenericUx>(),
      );
    });

    test(
      'an unattributed (null) error code maps to a retry-safe generic state',
      () {
        expect(mapBackendErrorToUx(null, 'timeout'), isA<RetrySafeGenericUx>());
      },
    );

    test('integrity_rejected maps to a neutral integrity hold', () {
      expect(
        mapBackendErrorToUx('integrity_rejected', 'x'),
        isA<IntegrityHoldUx>(),
      );
    });
  });

  group('defaultBackendErrorCopy', () {
    test('never returns the raw server message verbatim', () {
      const raw = 'relation "public.secret_table" does not exist';
      final state = mapBackendErrorToUx('internal_error', raw);
      final copy = defaultBackendErrorCopy(state);
      expect(copy.contains('secret_table'), isFalse);
    });

    test('every UX state has non-empty default copy', () {
      for (final code in [
        'stale_sequence',
        'idempotency_conflict',
        'invalid_transition',
        'unauthenticated',
        'forbidden',
        'invalid_payload',
        'completion_requirements_not_met',
        'integrity_rejected',
        null,
      ]) {
        final state = mapBackendErrorToUx(code, 'msg');
        expect(defaultBackendErrorCopy(state), isNotEmpty);
      }
    });
  });
}
