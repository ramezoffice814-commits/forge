import 'package:flutter/material.dart';

import '../../../shared/widgets/tab_placeholder_page.dart';

/// Rank tab root. Real content (weekly league podium, ranked list, seasonal
/// view) lands in a later roadmap item.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderPage(
      title: 'Rank',
      icon: Icons.emoji_events_outlined,
      description:
          'The weekly league podium and ranked list land in a later '
          'roadmap item.',
    );
  }
}
