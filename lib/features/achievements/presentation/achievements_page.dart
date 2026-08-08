import 'package:flutter/material.dart';

import '../../progression/presentation/pages/achievements_grid_page.dart';

/// Awards tab root — hosts the real locked/progressing/unlocked
/// achievements grid.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AchievementsGridPage();
  }
}
