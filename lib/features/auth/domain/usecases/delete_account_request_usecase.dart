import '../auth_repository.dart';

/// Placeholder — account deletion has no backend yet (see the roadmap
/// item's "out of scope" list). Every [AuthRepository] implementation
/// throws `ForgeAuthException(NotSupportedYetFailure())` here; this
/// use case exists so the call site and its eventual UI can be wired up
/// now without pretending deletion actually works.
class DeleteAccountRequestUseCase {
  const DeleteAccountRequestUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.requestAccountDeletion();
}
