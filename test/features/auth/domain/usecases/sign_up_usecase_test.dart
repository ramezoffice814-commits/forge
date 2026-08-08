import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/data/mock/mock_auth_repository.dart';
import 'package:forge/features/auth/domain/auth_failure.dart';
import 'package:forge/features/auth/domain/usecases/sign_up_usecase.dart';

import '../../../../support/fake_secure_key_value_store.dart';

void main() {
  late SignUpUseCase useCase;

  setUp(() {
    useCase = SignUpUseCase(MockAuthRepository(FakeSecureKeyValueStore()));
  });

  test('creates a new account with a fresh email', () async {
    final session = await useCase.call(
      displayName: 'Alex Rivera',
      email: 'alex@forge.app',
      password: 'longpassword1',
    );

    expect(session.user.displayName, 'Alex Rivera');
    expect(session.user.email, 'alex@forge.app');
    expect(session.user.onboardingCompleted, isTrue);
  });

  test('throws EmailAlreadyInUseFailure for the seeded demo email', () async {
    await expectLater(
      useCase.call(
        displayName: 'Someone Else',
        email: 'demo@forge.app',
        password: 'longpassword1',
      ),
      throwsA(
        isA<ForgeAuthException>().having(
          (e) => e.failure,
          'failure',
          isA<EmailAlreadyInUseFailure>(),
        ),
      ),
    );
  });

  test(
    'throws WeakPasswordFailure for a password under 8 characters',
    () async {
      await expectLater(
        useCase.call(
          displayName: 'Alex Rivera',
          email: 'alex2@forge.app',
          password: 'short1',
        ),
        throwsA(
          isA<ForgeAuthException>().having(
            (e) => e.failure,
            'failure',
            isA<WeakPasswordFailure>(),
          ),
        ),
      );
    },
  );
}
