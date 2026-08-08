import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import '../../../../../shared/widgets/forge_button.dart';
import 'duration_format.dart';
import 'progress_update_callback.dart';

class CodingSessionProgressControl extends StatelessWidget {
  const CodingSessionProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final CodingSessionProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final ratio = state.targetDuration.inSeconds == 0
        ? 0.0
        : (state.accumulatedActiveDuration.inSeconds /
                  state.targetDuration.inSeconds)
              .clamp(0, 1)
              .toDouble();

    void addMinutes(int minutes) {
      onUpdate(
        CodingSessionProgressState(
          accumulatedActiveDuration:
              state.accumulatedActiveDuration + Duration(minutes: minutes),
          targetDuration: state.targetDuration,
          checklist: state.checklist,
          completedItemIds: state.completedItemIds,
        ),
      );
    }

    void toggleItem(String itemId, bool checked) {
      final updated = Set<String>.of(state.completedItemIds);
      if (checked) {
        updated.add(itemId);
      } else {
        updated.remove(itemId);
      }
      onUpdate(
        CodingSessionProgressState(
          accumulatedActiveDuration: state.accumulatedActiveDuration,
          targetDuration: state.targetDuration,
          checklist: state.checklist,
          completedItemIds: updated,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatProgressDuration(state.accumulatedActiveDuration)} / '
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
              label: '+5 min',
              variant: ForgeButtonVariant.secondary,
              onPressed: enabled ? () => addMinutes(5) : null,
            ),
            ForgeButton(
              label: '+15 min',
              variant: ForgeButtonVariant.secondary,
              onPressed: enabled ? () => addMinutes(15) : null,
            ),
          ],
        ),
        if (state.checklist.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.space2),
          for (final item in state.checklist)
            CheckboxListTile(
              value: state.completedItemIds.contains(item.id),
              onChanged: enabled
                  ? (checked) => toggleItem(item.id, checked ?? false)
                  : null,
              title: Text(item.label),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
        ],
      ],
    );
  }
}
