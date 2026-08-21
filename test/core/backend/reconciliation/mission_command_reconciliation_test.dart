import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/reconciliation/mission_command_reconciliation.dart';
import 'package:forge/core/backend/responses/server_validation_status.dart';

void main() {
  group('MissionCommandReconciliation.reconcile', () {
    test('a well-formed accepted response reconciles to accepted', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: ServerValidationStatus.accepted,
      );
      expect(result.outcome, ReconciliationOutcome.accepted);
      expect(result.requiresUserAttention, isFalse);
    });

    test('a well-formed rejected response reconciles to rejectedByServer', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: ServerValidationStatus.rejected,
      );
      expect(result.outcome, ReconciliationOutcome.rejectedByServer);
    });

    test('a pending status is unsafe to auto-resolve', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: ServerValidationStatus.pending,
      );
      expect(result.outcome, ReconciliationOutcome.conflict);
      expect(result.requiresUserAttention, isTrue);
    });

    test('stale_sequence reconciles to staleSequence', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'stale_sequence',
      );
      expect(result.outcome, ReconciliationOutcome.staleSequence);
      expect(result.requiresUserAttention, isFalse);
    });

    test('out_of_order reconciles to serverAhead', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'out_of_order',
      );
      expect(result.outcome, ReconciliationOutcome.serverAhead);
    });

    test('duplicate_command reconciles to idempotencyReplay', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'duplicate_command',
      );
      expect(result.outcome, ReconciliationOutcome.idempotencyReplay);
    });

    test('idempotency_conflict requires user attention', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'idempotency_conflict',
      );
      expect(result.outcome, ReconciliationOutcome.conflict);
      expect(result.requiresUserAttention, isTrue);
    });

    test('internal_error requires user attention, never silently retried', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'internal_error',
      );
      expect(result.outcome, ReconciliationOutcome.conflict);
      expect(result.requiresUserAttention, isTrue);
    });

    test('invalid_transition is a clean rejection, not a conflict', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'invalid_transition',
      );
      expect(result.outcome, ReconciliationOutcome.rejectedByServer);
      expect(result.requiresUserAttention, isFalse);
    });

    test('mission_not_found is a clean rejection', () {
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'mission_not_found',
      );
      expect(result.outcome, ReconciliationOutcome.rejectedByServer);
    });
  });

  group('MissionSubmissionReconciliation.reconcile', () {
    final reward = const ConfirmedMissionReward(
      confirmedXpReward: 12,
      confirmedTotalXp: 12,
      previousLevel: 1,
      newLevel: 1,
      achievementUpdates: ['first-steps'],
      competitionScoreUpdate: 8.8,
    );

    test('accepted submission carries the reward through', () {
      final outcome = MissionSubmissionReconciliation.reconcile(
        serverStatus: ServerValidationStatus.accepted,
        reward: reward,
      );
      expect(outcome.base.outcome, ReconciliationOutcome.accepted);
      expect(outcome.reward, same(reward));
    });

    test(
      'rejected submission never carries reward data, even if a caller passed some',
      () {
        final outcome = MissionSubmissionReconciliation.reconcile(
          serverStatus: ServerValidationStatus.rejected,
          errorCode: 'completion_requirements_not_met',
          reward: reward,
        );
        expect(outcome.base.outcome, ReconciliationOutcome.rejectedByServer);
        expect(outcome.reward, isNull);
      },
    );

    test('a conflicted submission never carries reward data', () {
      final outcome = MissionSubmissionReconciliation.reconcile(
        serverStatus: null,
        errorCode: 'idempotency_conflict',
        reward: reward,
      );
      expect(outcome.base.outcome, ReconciliationOutcome.conflict);
      expect(outcome.reward, isNull);
    });
  });
}
