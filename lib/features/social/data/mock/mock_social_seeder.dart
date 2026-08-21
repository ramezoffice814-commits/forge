import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/enums/friend_request_status.dart';
import '../../domain/repositories/social_repository.dart';
import 'mock_social_catalog.dart';

/// Which fixed starting scenario a fresh local session begins in — mirrors
/// `DashboardMockScenario`'s "every scenario always returns exactly the
/// same data" convention, so widget/golden tests stay stable.
enum SocialMockScenario { normal, empty }

/// Seeds a brand-new user's social graph directly through the repository
/// (never fabricating a `PublicProfile` inline) so a fresh session isn't a
/// completely empty page by default — same reasoning as
/// `MockProgressionContext.seed`.
abstract final class MockSocialSeeder {
  static Future<void> seed(
    SocialRepository repository, {
    required String userId,
    required SocialMockScenario scenario,
    DateTime? now,
  }) async {
    if (scenario == SocialMockScenario.empty) return;

    final effectiveNow = now ?? MockSocialCatalog.referenceInstant;
    final mockIds = MockSocialCatalog.mockUserIds;

    // Two already-accepted friendships.
    for (final friendId in mockIds.take(2)) {
      await repository.createFriendship(
        Friendship(
          userId: userId,
          friendId: friendId,
          createdAt: effectiveNow.subtract(const Duration(days: 10)),
        ),
      );
    }

    // One incoming pending request from a third mock user.
    final requesterId = mockIds[2];
    await repository.createRequest(
      FriendRequest(
        id: '$requesterId-$userId-seed',
        senderId: requesterId,
        receiverId: userId,
        status: FriendRequestStatus.pending,
        createdAt: effectiveNow.subtract(const Duration(hours: 6)),
      ),
    );
  }
}
