import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../domain/entities/achievement_definition.dart';
import '../../domain/entities/achievement_progress.dart';

/// Renders one achievement in whichever of its three states currently
/// applies. Hidden-until-unlocked achievements never reveal their real name
/// or description before they're actually unlocked (spec section 19) — the
/// card shows a generic "???" placeholder instead.
class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final definition = progress.definition;
    final isUnlocked = progress.status == AchievementStatus.unlocked;
    final isHiddenAndLocked = definition.hiddenUntilUnlocked && !isUnlocked;

    final displayName = isHiddenAndLocked
        ? 'Hidden Achievement'
        : definition.name;
    final displayDescription = isHiddenAndLocked
        ? 'Keep going — this one reveals itself when you earn it.'
        : definition.description;

    final statusLabel = switch (progress.status) {
      AchievementStatus.locked => 'Locked',
      AchievementStatus.progressing => 'In progress',
      AchievementStatus.unlocked => 'Unlocked',
    };

    return Semantics(
      label: '$displayName. $statusLabel.',
      child: ForgeCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(progress.status),
                color: isUnlocked
                    ? tokens.accent
                    : tokens.text.withValues(alpha: 0.4),
              ),
              SizedBox(width: tokens.spacing.space2),
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!isHiddenAndLocked)
                ForgeTag(
                  label: _rarityLabel(definition.rarity),
                  variant: isUnlocked
                      ? ForgeTagVariant.accent
                      : ForgeTagVariant.neutral,
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.space1),
          Text(
            displayDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.text.withValues(alpha: 0.7),
            ),
          ),
          if (progress.status == AchievementStatus.progressing) ...[
            SizedBox(height: tokens.spacing.space2),
            ClipRRect(
              borderRadius: tokens.radius.smRadius,
              child: LinearProgressIndicator(
                value: progress.fraction,
                color: tokens.accent,
                backgroundColor: tokens.divider,
              ),
            ),
            SizedBox(height: tokens.spacing.space1),
            Text(
              '${progress.current} / ${progress.target}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(AchievementStatus status) => switch (status) {
    AchievementStatus.locked => Icons.lock_outline_rounded,
    AchievementStatus.progressing => Icons.hourglass_top_rounded,
    AchievementStatus.unlocked => Icons.emoji_events_rounded,
  };

  static String _rarityLabel(AchievementRarity rarity) => switch (rarity) {
    AchievementRarity.common => 'Common',
    AchievementRarity.uncommon => 'Uncommon',
    AchievementRarity.rare => 'Rare',
    AchievementRarity.epic => 'Epic',
  };
}
