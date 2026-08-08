import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/data/mock/mock_auth_repository.dart';
import 'package:forge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:forge/features/auth/domain/usecases/sign_in_usecase.dart';

import '../../../../support/fake_secure_key_value_store.dart';

void main() {
  test('returns null when no session was ever persisted', () async {
    final repo = MockAuthRepository(FakeSecureKeyValueStore());
    final useCase = RestoreSessionUseCase(repo);

    expect(await useCase.call(), isNull);
  });

  test(
    'reconstructs a previously-persisted session without needing the password again',
    () async {
      final store = FakeSecureKeyValueStore();
      final repo = MockAuthRepository(store);
      await SignInUseCase(
        repo,
      ).call(email: 'demo@forge.app', password: 'forgepass1');

      // A fresh repository instance sharing the same store simulates a real
      // process restart: nothing in-memory survives except what was
      // persisted.
      final restoredRepo = MockAuthRepository(store);
      final restored = await RestoreSessionUseCase(restoredRepo).call();

      expect(restored, isNotNull);
      expect(restored!.user.email, 'demo@forge.app');
    },
  );
}
