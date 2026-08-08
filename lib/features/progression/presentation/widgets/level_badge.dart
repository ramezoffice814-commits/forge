import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_progress_ring.dart';

/// A compact level indicator for reuse outside the full Progression page
/// (Dashboard, Profile) — deliberately small, never the page's main focus.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.levelNumber,
    required this.levelTitle,
    required this.progressToNextLevel,
    this.size = 56,
  });

  final int levelNumber;
  final String levelTitle;
  final double progressToNextLevel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Semantics(
      label:
          'Level $levelNumber, $levelTitle. '
          '${(progressToNextLevel * 100).round()} percent to next level.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ForgeProgressRing(
            progress: progressToNextLevel,
            size: size,
            strokeWidth: 5,
            child: Text(
              '$levelNumber',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(width: tokens.spacing.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level $levelNumber',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                levelTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
