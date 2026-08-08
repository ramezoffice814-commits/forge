import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import 'progress_update_callback.dart';

class CounterProgressControl extends StatelessWidget {
  const CounterProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final CounterProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final canDecrement = enabled && state.currentCount > 0;
    final canIncrement = enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.currentCount} / ${state.targetCount} ${state.unit}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.space2),
        LinearProgressIndicator(
          value: (state.currentCount / state.targetCount).clamp(0, 1),
          color: tokens.accent,
          backgroundColor: tokens.divider,
        ),
        SizedBox(height: tokens.spacing.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: canDecrement
                  ? () => onUpdate(
                      CounterProgressState(
                        currentCount: state.currentCount - 1,
                        targetCount: state.targetCount,
                        unit: state.unit,
                      ),
                      isCorrection: true,
                    )
                  : null,
              icon: const Icon(Icons.remove_rounded),
              tooltip: 'Correct down by 1',
            ),
            SizedBox(width: tokens.spacing.space4),
            IconButton.filled(
              onPressed: canIncrement
                  ? () => onUpdate(
                      CounterProgressState(
                        currentCount: state.currentCount + 1,
                        targetCount: state.targetCount,
                        unit: state.unit,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add 1',
            ),
          ],
        ),
      ],
    );
  }
}
