import '../auth_repository.dart';

class RequestPasswordResetUseCase {
  const RequestPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) {
    return _repository.requestPasswordReset(email.trim().toLowerCase());
  }
}
