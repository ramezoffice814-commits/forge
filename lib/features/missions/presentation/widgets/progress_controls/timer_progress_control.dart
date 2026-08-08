import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import '../../../../../shared/widgets/forge_button.dart';
import 'duration_format.dart';
import 'progress_update_callback.dart';

/// Deliberately no live per-second ticking here — logging elapsed time is a
/// discrete user action (see spec's "no per-second/per-frame events" rule).
/// The mission's actual session clock (start/pause/resume) is tracked
/// separately by `MissionSessionReducer`; this only records progress
/// *toward the target*.
class TimerProgressControl extends StatelessWidget {
  const TimerProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final TimerProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final ratio = state.targetDuration.inSeconds == 0
        ? 0.0
        : (state.accumulatedDuration.inSeconds / state.targetDuration.inSeconds)
              .clamp(0, 1)
              .toDouble();

    void addMinutes(int minutes) {
      onUpdate(
        TimerProgressState(
          accumulatedDuration:
              state.accumulatedDuration + Duration(minutes: minutes),
          targetDuration: state.targetDuration,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatProgressDuration(state.accumulatedDuration)} / '
          '${formatProgressDuration(state.targetDuration)}',
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
              label: '+1 min',
              variant: ForgeButtonVariant.secondary,
              onPressed: enabled ? () => addMinutes(1) : null,
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
