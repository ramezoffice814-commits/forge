import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/usecases/get_pending_requests_usecase.dart';

/// One incoming pending request, with the sender's public profile already
/// resolved (see `PendingFriendRequestView`) — never shows anything about
/// the sender beyond their public profile fields.
class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.view,
    required this.onAccept,
    required this.onReject,
  });

  final PendingFriendRequestView view;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final profile = view.senderProfile;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.space2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tokens.neutralRamp.c800,
            child: Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          SizedBox(width: tokens.spacing.space3),
          Expanded(
            child: Text(
              '${profile.displayName} wants to be friends',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Accept',
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Decline',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
