import '../entities/activity_event.dart';
import '../entities/friend_request.dart';
import '../entities/friendship.dart';
import '../entities/profile_visibility_settings.dart';
import '../entities/public_profile.dart';
import '../enums/friend_request_status.dart';

/// Local-only storage for the social graph, the deterministic mock
/// population's public profiles/activity, and per-user visibility
/// settings — never itself authoritative (no server-confirmed friendships
/// or feed exist yet in this phase).
abstract class SocialRepository {
  Future<List<FriendRequest>> incomingRequestsFor(String userId);

  /// Any request (pending, accepted, or rejected) between these two users
  /// in either direction — the input `SendFriendRequestUseCase`'s
  /// duplicate check is built from.
  Future<FriendRequest?> existingRequestBetween(String userIdA, String userIdB);

  Future<FriendRequest?> getRequestById(String requestId);
  Future<FriendRequest> createRequest(FriendRequest request);
  Future<void> updateRequestStatus(
    String requestId,
    FriendRequestStatus status,
  );

  Future<bool> areFriends(String userIdA, String userIdB);
  Future<List<Friendship>> friendshipsFor(String userId);
  Future<void> createFriendship(Friendship friendship);
  Future<void> removeFriendship(String userIdA, String userIdB);

  /// The deterministic mock population's public profile for [userId], or
  /// `null` if [userId] isn't a known mock user (the real signed-in user's
  /// own profile is never looked up this way — see
  /// `GetPublicProfileUseCase`).
  Future<PublicProfile?> getMockPublicProfile(String userId);

  /// The seeded activity feed entries belonging to any of [userIds].
  Future<List<ActivityEvent>> activityFeedFor(List<String> userIds);

  Future<ProfileVisibilitySettings> getVisibilitySettings(String userId);
  Future<void> setVisibilitySettings(ProfileVisibilitySettings settings);

  void clearForUser(String userId);
}
