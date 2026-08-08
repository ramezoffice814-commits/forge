import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../domain/entities/dialogue_line.dart';

/// Always-visible subtitle track for the active [DialogueLine]. Reveals the
/// full line at once (no typewriter effect — it would only hurt
/// readability and conflicts with reduced-motion/screen-reader use), and
/// expands to fit at large text scale rather than clipping.
class DialogueSubtitlePanel extends StatelessWidget {
  const DialogueSubtitlePanel({
    super.key,
    required this.characterName,
    required this.line,
    required this.lineNumber,
    required this.totalLines,
    required this.ttsUnavailableNotice,
  });

  final String characterName;
  final DialogueLine? line;
  final int lineNumber;
  final int totalLines;

  /// True when TTS could not be used for this transmission — shown as a
  /// small, non-blocking notice; subtitles remain fully functional.
  final bool ttsUnavailableNotice;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final text = line?.text ?? '';

    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              characterName.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.accent,
                letterSpacing: 1.2,
              ),
            ),
            if (totalLines > 0)
              Semantics(
                label: 'Line $lineNumber of $totalLines',
                child: ExcludeSemantics(
                  child: Text(
                    '$lineNumber / $totalLines',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.space2),
        Text(
          text,
          key: const ValueKey('dialogue-subtitle-text'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (ttsUnavailableNotice) ...[
          SizedBox(height: tokens.spacing.space2),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  Icons.volume_off_rounded,
                  size: 14,
                  color: tokens.text.withValues(alpha: 0.5),
                ),
                SizedBox(width: tokens.spacing.space2),
                Expanded(
                  child: Text(
                    'Voice unavailable on this device — subtitles continue.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.5),
                    ),
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
