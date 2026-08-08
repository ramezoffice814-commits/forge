import '../auth_repository.dart';
import '../entities/auth_session.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  /// Confirm-password matching is a form-level (presentation) concern —
  /// by the time it reaches here, [password] is already validated.
  Future<AuthSession> call({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _repository.signUp(
      displayName: displayName.trim(),
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}
