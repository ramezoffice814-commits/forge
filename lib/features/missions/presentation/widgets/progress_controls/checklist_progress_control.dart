import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import 'progress_update_callback.dart';

class ChecklistProgressControl extends StatelessWidget {
  const ChecklistProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final ChecklistProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    void toggle(String itemId, bool checked) {
      final updated = Set<String>.of(state.completedItemIds);
      if (checked) {
        updated.add(itemId);
      } else {
        updated.remove(itemId);
      }
      onUpdate(
        ChecklistProgressState(items: state.items, completedItemIds: updated),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.completedItemIds.length} / ${state.items.length} done',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.space2),
        for (final item in state.items)
          CheckboxListTile(
            value: state.completedItemIds.contains(item.id),
            onChanged: enabled
                ? (checked) => toggle(item.id, checked ?? false)
                : null,
            title: Text(item.label),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
      ],
    );
  }
}
