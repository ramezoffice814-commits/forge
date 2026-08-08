import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import '../../../../../shared/widgets/forge_button.dart';
import 'duration_format.dart';
import 'progress_update_callback.dart';

class ReadingProgressControl extends StatelessWidget {
  const ReadingProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final ReadingProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final ratio = state.targetDuration.inSeconds == 0
        ? 0.0
        : (state.durationRead.inSeconds / state.targetDuration.inSeconds)
              .clamp(0, 1)
              .toDouble();

    void addMinutes(int minutes) {
      onUpdate(
        ReadingProgressState(
          durationRead: state.durationRead + Duration(minutes: minutes),
          targetDuration: state.targetDuration,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatProgressDuration(state.durationRead)} / '
          '${formatProgressDuration(state.targetDuration)} read',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.space2),
        LinearProgressIndicator(
          value: ratio,
          color: tokens.accent,
          backgroundColor: tokens.divider,
        ),
        SizedBox(height: tokens.spacing.space3),
        Wrap(
          spacing: tokens.spacing.space2,
          children: [
            ForgeButton(
              label: '+2 min',
              variant: ForgeButtonVariant.secondary,
              onPressed: enabled ? () => addMinutes(2) : null,
            ),
            ForgeButton(
              label: '+5 min',
              variant: ForgeButtonVariant.secondary,
              onPressed: enabled ? () => addMinutes(5) : null,
            ),
          ],
        ),
      ],
    );
  }
}
