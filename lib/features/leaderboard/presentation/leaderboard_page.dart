import 'package:flutter/material.dart';

import '../../competition/presentation/pages/competition_page.dart';

/// Rank tab root — hosts the real Fair Competition experience (My League,
/// Season, Hall of Fame). Same "thin tab-root wrapper" convention as
/// `ProgressPage`/`ProgressionPage`.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompetitionPage();
  }
}
