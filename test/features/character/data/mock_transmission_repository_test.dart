import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/character/data/mock/mock_transmission_repository.dart';
import 'package:forge/features/character/domain/repositories/transmission_repository.dart';

import '../../../support/fake_dashboard_overrides.dart';

void main() {
  final dashboard = buildTestDashboardOverview(displayName: 'Ramez');

  Future<T> expectThrows<T extends Exception>(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (e) {
      expect(e, isA<T>());
      return e as T;
    }
    fail('Expected $T to be thrown');
  }

  test(
    'normalActive is deterministic and interpolates the display name',
    () async {
      const repo = MockTransmissionRepository(
        scenario: TransmissionMockScenario.normalActive,
      );
      final first = await repo.getDailyTransmission(dashboard);
      final second = await repo.getDailyTransmission(dashboard);

      expect(first.id, second.id);
      expect(first.dialogueLines.first.text, contains('Ramez'));
      expect(first.dialogueLines, isNotEmpty);
    },
  );

  test('firstDay welcomes the user by name', () async {
    const repo = MockTransmissionRepository(
      scenario: TransmissionMockScenario.firstDay,
    );
    final script = await repo.getDailyTransmission(dashboard);
    expect(script.dialogueLines.first.text, contains('Ramez'));
    expect(script.requiresProof, isFalse);
  });

  test('recovery avoids shaming language', () async {
    const repo = MockTransmissionRepository(
      scenario: TransmissionMockScenario.recovery,
    );
    final script = await repo.getDailyTransmission(dashboard);
    for (final phrase in ['failed', 'broke', 'ruined', 'lazy']) {
      expect(
        script.fullTranscript.toLowerCase(),
        isNot(contains(phrase)),
        reason: phrase,
      );
    }
  });

  test('completedReplay describes the mission as already done', () async {
    const repo = MockTransmissionRepository(
      scenario: TransmissionMockScenario.completedReplay,
    );
    final script = await repo.getDailyTransmission(dashboard);
    expect(script.fullTranscript, contains('already complete'));
  });

  test('offline scenario throws TransmissionOfflineException', () async {
    const repo = MockTransmissionRepository(
      scenario: TransmissionMockScenario.offline,
    );
    await expectThrows<TransmissionOfflineException>(
      () => repo.getDailyTransmission(dashboard),
    );
  });

  test('repositoryError scenario throws TransmissionException', () async {
    const repo = MockTransmissionRepository(
      scenario: TransmissionMockScenario.repositoryError,
    );
    await expectThrows<TransmissionException>(
      () => repo.getDailyTransmission(dashboard),
    );
  });
}
