import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/enums/activity_event_type.dart';

/// One activity feed entry — renders only [ActivityEvent.headline], a
/// precomputed public-safe string; never interpolates any other field
/// into user-visible text.
class ActivityFeedTile extends StatelessWidget {
  const ActivityFeedTile({super.key, required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final icon = switch (event.type) {
      ActivityEventType.achievementUnlocked => Icons.military_tech_outlined,
      ActivityEventType.levelReached => Icons.trending_up_rounded,
      ActivityEventType.competitionMilestone => Icons.emoji_events_outlined,
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.space1),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.accent),
          SizedBox(width: tokens.spacing.space2),
          Expanded(
            child: Text(
              event.headline,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
