import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../../dashboard/domain/entities/mission_preview.dart'
    show MissionDifficulty;
import '../../domain/entities/transmission_script.dart';

String missionDifficultyLabel(MissionDifficulty difficulty) {
  return switch (difficulty) {
    MissionDifficulty.easy => 'Easy',
    MissionDifficulty.moderate => 'Moderate',
    MissionDifficulty.hard => 'Hard',
  };
}

/// Renders the mission a [TransmissionScript] reveals — tags, title,
/// description, and completion conditions. Shown once the transmission
/// reaches mission reveal (or later); acceptance itself is a separate
/// control ([AcceptMissionButton]) so this panel is pure display.
class MissionRevealPanel extends StatelessWidget {
  const MissionRevealPanel({super.key, required this.script});

  final TransmissionScript script;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ForgeCard(
      elevation: ForgeCardElevation.md,
      children: [
        Text("TODAY'S MISSION", style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space2),
        Wrap(
          spacing: tokens.spacing.space2,
          runSpacing: tokens.spacing.space2,
          children: [
            ForgeTag(
              label: '+${script.xpReward} XP',
              variant: ForgeTagVariant.accent,
            ),
            ForgeTag(
              label: missionDifficultyLabel(script.difficulty),
              variant: ForgeTagVariant.outline,
            ),
            ForgeTag(
              label: '~${script.estimatedMinutes} min',
              variant: ForgeTagVariant.neutral,
            ),
            ForgeTag(label: script.category, variant: ForgeTagVariant.neutral),
            if (script.requiresProof)
              const ForgeTag(
                label: 'Proof required',
                variant: ForgeTagVariant.outline,
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.space3),
        Text(
          script.missionTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: tokens.spacing.space2),
        Text(
          script.missionDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.text.withValues(alpha: 0.75),
          ),
        ),
        if (script.completionConditions.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.space3),
          for (final condition in script.completionConditions)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.space1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: tokens.text.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: tokens.spacing.space2),
                  Expanded(
                    child: Text(
                      condition,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
