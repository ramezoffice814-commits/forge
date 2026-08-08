import 'package:flutter/material.dart';

import '../../progression/presentation/pages/progression_page.dart';

/// Progress tab root — hosts the real Progression experience (level, XP
/// preview, title, category growth). The week-bars/heatmap stat cards
/// originally sketched for this tab land in a later roadmap item as an
/// additional section of this same page.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProgressionPage();
  }
}
