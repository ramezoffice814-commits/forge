import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';
import 'forge_button.dart';
import 'forge_card.dart';
import 'forge_scaffold.dart';
import 'forge_tag.dart';

/// TEMPORARY placeholder for a bottom-nav tab's root screen. Every tab uses
/// this today — real feature content (dashboard, leaderboard, progress,
/// achievements, profile) replaces it one roadmap item at a time.
///
/// Carries a small tap counter purely to make tab-state preservation
/// demonstrable/testable (switching tabs and back should not reset it,
/// since [StatefulShellRoute.indexedStack] keeps each branch mounted) —
/// it is not a real feature, just a verification aid for this milestone.
class TabPlaceholderPage extends StatefulWidget {
  const TabPlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  State<TabPlaceholderPage> createState() => _TabPlaceholderPageState();
}

class _TabPlaceholderPageState extends State<TabPlaceholderPage> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ForgeScaffold(
      appBarTitle: widget.title,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.space6),
          child: ForgeCard(
            elevation: ForgeCardElevation.sm,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 40, color: tokens.accent),
              SizedBox(height: tokens.spacing.space3),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: tokens.spacing.space2),
              const ForgeTag(
                label: 'TEMPORARY PLACEHOLDER',
                variant: ForgeTagVariant.outline,
              ),
              SizedBox(height: tokens.spacing.space3),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: tokens.spacing.space4),
              Text(
                'Tapped $_tapCount times',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.space2),
              ForgeButton(
                label: 'Tap (verifies tab state survives switching)',
                variant: ForgeButtonVariant.ghost,
                onPressed: () => setState(() => _tapCount++),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
