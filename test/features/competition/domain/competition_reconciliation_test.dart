import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/services/competition_reconciliation.dart';

void main() {
  final now = DateTime.utc(2026, 8, 19);

  ConfirmedCompetitionContribution contribution(
    String missionInstanceId,
    double delta,
  ) {
    return ConfirmedCompetitionContribution(
      missionInstanceId: missionInstanceId,
      confirmedScoreDelta: delta,
      integrityStatus: 'clean',
      confirmedAt: now,
    );
  }

  group('appendConfirmed', () {
    test('accumulates distinct mission contributions', () {
      final list = CompetitionReconciliation.appendConfirmed(
        CompetitionReconciliation.appendConfirmed(
          const [],
          contribution('m1', 8.8),
        ),
        contribution('m2', 6.0),
      );
      expect(list, hasLength(2));
    });

    test(
      'is idempotent per mission instance — a replayed confirmation is a no-op',
      () {
        final first = CompetitionReconciliation.appendConfirmed(
          const [],
          contribution('m1', 8.8),
        );
        final second = CompetitionReconciliation.appendConfirmed(
          first,
          contribution('m1', 8.8),
        );
        expect(second, hasLength(1));
        expect(identical(first, second), isTrue);
      },
    );
  });

  group('totalConfirmedScore', () {
    test('sums every distinct confirmed contribution', () {
      final list = [contribution('m1', 8.8), contribution('m2', 6.0)];
      expect(
        CompetitionReconciliation.totalConfirmedScore(list),
        closeTo(14.8, 0.0001),
      );
    });

    test('an empty list totals to zero, never null or an error', () {
      expect(CompetitionReconciliation.totalConfirmedScore(const []), 0);
    });
  });
}
