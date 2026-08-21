import '../entities/public_profile.dart';
import '../repositories/social_repository.dart';

/// Resolves a user's accepted friendships into their friends' public
/// profiles — friends in this local/mock phase are always drawn from the
/// deterministic mock population, never fabricated on the fly.
class GetFriendsUseCase {
  const GetFriendsUseCase(this._repository);

  final SocialRepository _repository;

  Future<List<PublicProfile>> call(String userId) async {
    final friendships = await _repository.friendshipsFor(userId);
    final profiles = <PublicProfile>[];
    for (final friendship in friendships) {
      final friendId = friendship.otherUserId(userId);
      final profile = await _repository.getMockPublicProfile(friendId);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }
}
