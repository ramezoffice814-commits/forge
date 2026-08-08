import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/data/mock/mock_auth_repository.dart';
import 'package:forge/features/auth/domain/auth_failure.dart';
import 'package:forge/features/auth/domain/usecases/sign_in_usecase.dart';

import '../../../../support/fake_secure_key_value_store.dart';

void main() {
  late SignInUseCase useCase;

  setUp(() {
    useCase = SignInUseCase(MockAuthRepository(FakeSecureKeyValueStore()));
  });

  test('signs in the seeded demo account', () async {
    final session = await useCase.call(
      email: 'demo@forge.app',
      password: 'forgepass1',
    );

    expect(session.user.email, 'demo@forge.app');
    expect(session.accessToken, isNotEmpty);
  });

  test(
    'normalizes email (trims and lowercases) before checking credentials',
    () async {
      final session = await useCase.call(
        email: '  DEMO@forge.app  ',
        password: 'forgepass1',
      );

      expect(session.user.email, 'demo@forge.app');
    },
  );

  test('throws InvalidCredentialsFailure for a wrong password', () async {
    await expectLater(
      useCase.call(email: 'demo@forge.app', password: 'wrong-password'),
      throwsA(
        isA<ForgeAuthException>().having(
          (e) => e.failure,
          'failure',
          isA<InvalidCredentialsFailure>(),
        ),
      ),
    );
  });

  test('throws InvalidCredentialsFailure for an unknown email', () async {
    await expectLater(
      useCase.call(email: 'nobody@forge.app', password: 'whatever1'),
      throwsA(
        isA<ForgeAuthException>().having(
          (e) => e.failure,
          'failure',
          isA<InvalidCredentialsFailure>(),
        ),
      ),
    );
  });
}
