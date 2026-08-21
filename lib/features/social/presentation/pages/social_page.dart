import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_empty_state.dart';
import '../../../../shared/widgets/forge_error_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../providers/social_controller.dart';
import '../providers/social_state.dart';
import '../widgets/activity_feed_tile.dart';
import '../widgets/friend_list_tile.dart';
import '../widgets/friend_request_tile.dart';

/// The Social screen's real content — Friends, Requests, and an Activity
/// preview. Every value comes from `SocialController`; nothing here
/// resolves a friendship, evaluates a request, or reads private data.
class SocialPage extends ConsumerWidget {
  const SocialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(socialControllerProvider);
    return ForgeScaffold(
      appBarTitle: 'Social',
      body: _Body(state: state),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final SocialState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SocialLoading() => const ForgeLoadingState(
        message: 'Loading your friends…',
      ),
      SocialError(:final message) => ForgeErrorState(message: message),
      SocialReady ready => _SocialContent(state: ready),
    };
  }
}

class _SocialContent extends ConsumerWidget {
  const _SocialContent({required this.state});

  final SocialReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final notifier = ref.read(socialControllerProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.lastActionMessage != null) ...[
            Text(
              state.lastActionMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.accent),
            ),
            SizedBox(height: tokens.spacing.space3),
          ],
          if (state.pendingRequests.isNotEmpty) ...[
            Text('Requests', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spacing.space2),
            ForgeCard(
              children: [
                for (final view in state.pendingRequests)
                  FriendRequestTile(
                    view: view,
                    onAccept: () => notifier.acceptRequest(view.request.id),
                    onReject: () => notifier.rejectRequest(view.request.id),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.space4),
          ],
          Text('Friends', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spacing.space2),
          if (state.friends.isEmpty)
            const ForgeEmptyState(
              icon: Icons.people_outline,
              title: 'No friends yet',
              message: 'Accept a request to start building your friends list.',
            )
          else
            ForgeCard(
              children: [
                for (final friend in state.friends)
                  FriendListTile(
                    profile: friend,
                    onTap: () => context.goNamed(
                      AppRouteNames.publicProfile,
                      pathParameters: {'userId': friend.userId},
                    ),
                    onRemove: () => notifier.removeFriend(friend.userId),
                  ),
              ],
            ),
          SizedBox(height: tokens.spacing.space4),
          Text('Activity', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spacing.space2),
          if (state.activityFeed.isEmpty)
            const ForgeEmptyState(
              icon: Icons.timeline_outlined,
              title: 'No activity yet',
              message: "Your friends' milestones will show up here.",
            )
          else
            ForgeCard(
              children: [
                for (final event in state.activityFeed.take(10))
                  ActivityFeedTile(event: event),
              ],
            ),
        ],
      ),
    );
  }
}
