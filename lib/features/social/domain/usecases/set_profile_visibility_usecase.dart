import '../entities/profile_visibility_settings.dart';
import '../enums/profile_visibility.dart';
import '../repositories/social_repository.dart';

class SetProfileVisibilityUseCase {
  const SetProfileVisibilityUseCase(this._repository);

  final SocialRepository _repository;

  Future<void> call(
    String userId,
    ProfileVisibility visibility, {
    DateTime? now,
  }) async {
    await _repository.setVisibilitySettings(
      ProfileVisibilitySettings(
        userId: userId,
        visibility: visibility,
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }
}
