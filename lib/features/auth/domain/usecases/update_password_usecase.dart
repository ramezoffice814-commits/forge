import '../auth_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String newPassword) {
    return _repository.updatePassword(newPassword);
  }
}
