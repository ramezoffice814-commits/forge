import '../entities/activity_event.dart';
import '../repositories/social_repository.dart';

/// The activity feed only ever shows a user's own friends' events — never
/// a global feed, and never anything from a non-friend (spec section 3:
/// "only public-safe events," scoped further here to "only from people
/// you're actually friends with").
class GetActivityFeedUseCase {
  const GetActivityFeedUseCase(this._repository);

  final SocialRepository _repository;

  Future<List<ActivityEvent>> call(String userId) async {
    final friendships = await _repository.friendshipsFor(userId);
    final friendIds = friendships
        .map((friendship) => friendship.otherUserId(userId))
        .toList();

    final events = await _repository.activityFeedFor(friendIds);
    final sorted = [...events]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted;
  }
}
