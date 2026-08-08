import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import '../../../../../shared/widgets/forge_button.dart';
import 'progress_update_callback.dart';

class BinaryProgressControl extends StatelessWidget {
  const BinaryProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final BinaryProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      children: [
        Icon(
          state.completed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: state.completed
              ? tokens.accent
              : tokens.text.withValues(alpha: 0.5),
        ),
        SizedBox(width: tokens.spacing.space2),
        Expanded(
          child: Text(
            state.completed ? 'Marked as done' : 'Not marked as done yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        ForgeButton(
          label: state.completed ? 'Unmark' : 'Mark done',
          variant: state.completed
              ? ForgeButtonVariant.secondary
              : ForgeButtonVariant.primary,
          onPressed: enabled
              ? () => onUpdate(BinaryProgressState(completed: !state.completed))
              : null,
        ),
      ],
    );
  }
}
