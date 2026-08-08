import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import 'progress_update_callback.dart';

class QuantityProgressControl extends StatelessWidget {
  const QuantityProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final QuantityProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final canDecrement = enabled && state.currentValue > 0;
    final ratio = state.targetValue == 0
        ? 0.0
        : (state.currentValue / state.targetValue).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.currentValue} / ${state.targetValue} ${state.unit}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.space2),
        LinearProgressIndicator(
          value: ratio,
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
                      QuantityProgressState(
                        currentValue: state.currentValue - 1,
                        targetValue: state.targetValue,
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
              onPressed: enabled
                  ? () => onUpdate(
                      QuantityProgressState(
                        currentValue: state.currentValue + 1,
                        targetValue: state.targetValue,
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
