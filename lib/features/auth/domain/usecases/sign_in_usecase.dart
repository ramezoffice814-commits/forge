import '../auth_repository.dart';
import '../entities/auth_session.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({required String email, required String password}) {
    return _repository.signIn(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}
