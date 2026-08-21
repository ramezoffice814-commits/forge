import '../../domain/entities/activity_event.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/entities/profile_visibility_settings.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/enums/friend_request_status.dart';
import '../../domain/repositories/social_repository.dart';
import '../mock/mock_social_catalog.dart';

/// The only repository implementation this phase ships — in-memory,
/// process-lifetime storage, same reasoning as
/// `InMemoryCompetitionRepository`: no native persistence dependency, and
/// nothing here is ever treated as a source of truth beyond "what this
/// device currently believes locally."
class InMemorySocialRepository implements SocialRepository {
  final Map<String, FriendRequest> _requestsById = {};
  final List<Friendship> _friendships = [];
  final Map<String, ProfileVisibilitySettings> _visibilityByUser = {};

  @override
  Future<List<FriendRequest>> incomingRequestsFor(String userId) async {
    return _requestsById.values
        .where(
          (r) =>
              r.receiverId == userId && r.status == FriendRequestStatus.pending,
        )
        .toList();
  }

  @override
  Future<FriendRequest?> existingRequestBetween(
    String userIdA,
    String userIdB,
  ) async {
    final matches =
        _requestsById.values
            .where(
              (r) =>
                  (r.senderId == userIdA && r.receiverId == userIdB) ||
                  (r.senderId == userIdB && r.receiverId == userIdA),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<FriendRequest?> getRequestById(String requestId) async {
    return _requestsById[requestId];
  }

  @override
  Future<FriendRequest> createRequest(FriendRequest request) async {
    _requestsById[request.id] = request;
    return request;
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    FriendRequestStatus status,
  ) async {
    final existing = _requestsById[requestId];
    if (existing == null) return;
    _requestsById[requestId] = existing.copyWith(status: status);
  }

  @override
  Future<bool> areFriends(String userIdA, String userIdB) async {
    return _friendships.any(
      (f) => f.involves(userIdA) && f.otherUserId(userIdA) == userIdB,
    );
  }

  @override
  Future<List<Friendship>> friendshipsFor(String userId) async {
    return _friendships.where((f) => f.involves(userId)).toList();
  }

  @override
  Future<void> createFriendship(Friendship friendship) async {
    if (await areFriends(friendship.userId, friendship.friendId)) return;
    _friendships.add(friendship);
  }

  @override
  Future<void> removeFriendship(String userIdA, String userIdB) async {
    _friendships.removeWhere(
      (f) => f.involves(userIdA) && f.otherUserId(userIdA) == userIdB,
    );
  }

  @override
  Future<PublicProfile?> getMockPublicProfile(String userId) async {
    return MockSocialCatalog.profileFor(userId);
  }

  @override
  Future<List<ActivityEvent>> activityFeedFor(List<String> userIds) async {
    return userIds.expand(MockSocialCatalog.activityFor).toList();
  }

  @override
  Future<ProfileVisibilitySettings> getVisibilitySettings(String userId) async {
    return _visibilityByUser[userId] ??
        ProfileVisibilitySettings.defaultFor(userId, DateTime.now());
  }

  @override
  Future<void> setVisibilitySettings(ProfileVisibilitySettings settings) async {
    _visibilityByUser[settings.userId] = settings;
  }

  @override
  void clearForUser(String userId) {
    _requestsById.removeWhere(
      (_, r) => r.senderId == userId || r.receiverId == userId,
    );
    _friendships.removeWhere((f) => f.involves(userId));
    _visibilityByUser.remove(userId);
  }
}
