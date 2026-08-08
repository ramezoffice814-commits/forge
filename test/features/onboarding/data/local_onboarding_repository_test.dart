import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/onboarding/data/local_onboarding_repository.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  test('is not completed before markCompleted is ever called', () async {
    final repo = LocalOnboardingRepository(FakeSecureKeyValueStore());
    expect(await repo.isCompleted(), isFalse);
  });

  test(
    'persists completion across repository instances sharing a store',
    () async {
      final store = FakeSecureKeyValueStore();
      await LocalOnboardingRepository(store).markCompleted();

      // A fresh instance over the same store simulates surviving a restart.
      final reopened = LocalOnboardingRepository(store);
      expect(await reopened.isCompleted(), isTrue);
    },
  );
}
