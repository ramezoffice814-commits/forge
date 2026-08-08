import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';
import '../../domain/aggregates/mission_aggregate.dart';
import '../../domain/enums/rejection_reason.dart';

/// Renders only the actions legal from the aggregate's *current* state —
/// this widget never re-derives lifecycle rules itself, it just reads the
/// `can*` getters `MissionAggregate` already exposes.
class MissionActionBar extends StatelessWidget {
  const MissionActionBar({
    super.key,
    required this.aggregate,
    required this.onAccept,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSubmit,
    required this.onReject,
    required this.onAbandon,
    required this.onUndoCompletion,
  });

  final MissionAggregate aggregate;
  final VoidCallback onAccept;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSubmit;
  final ValueChanged<RejectionReason> onReject;
  final VoidCallback onAbandon;
  final VoidCallback onUndoCompletion;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    final buttons = <Widget>[
      if (aggregate.canAccept)
        ForgeButton(label: 'Accept mission', onPressed: onAccept),
      if (aggregate.canStart) ForgeButton(label: 'Start', onPressed: onStart),
      if (aggregate.canPause)
        ForgeButton(
          label: 'Pause',
          variant: ForgeButtonVariant.secondary,
          onPressed: onPause,
        ),
      if (aggregate.canResume)
        ForgeButton(label: 'Resume', onPressed: onResume),
      if (aggregate.canSubmit)
        ForgeButton(label: 'Submit', onPressed: onSubmit),
      if (aggregate.canUndoCompletion)
        ForgeButton(
          label: 'Undo completion',
          variant: ForgeButtonVariant.secondary,
          onPressed: onUndoCompletion,
        ),
      if (aggregate.canReject)
        ForgeButton(
          label: 'Not today',
          variant: ForgeButtonVariant.ghost,
          onPressed: () => _showRejectSheet(context, onReject),
        ),
      if (aggregate.canAbandon)
        ForgeButton(
          label: 'Abandon',
          variant: ForgeButtonVariant.ghost,
          onPressed: onAbandon,
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: tokens.spacing.space2,
      runSpacing: tokens.spacing.space2,
      children: buttons,
    );
  }
}

Future<void> _showRejectSheet(
  BuildContext context,
  ValueChanged<RejectionReason> onReject,
) {
  final tokens = Theme.of(context).extension<ForgeTokens>()!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What's going on with this mission?",
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.space3),
              for (final reason in RejectionReason.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_reasonLabel(reason)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReject(reason);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

String _reasonLabel(RejectionReason reason) => switch (reason) {
  RejectionReason.tooDifficult => 'Too difficult right now',
  RejectionReason.tooLong => 'Takes too long today',
  RejectionReason.wrongCategory => "Not the right category",
  RejectionReason.inaccessible => "I can't do this one",
  RejectionReason.unsafe => "Doesn't feel safe for me",
  RejectionReason.notRelevant => "Not relevant to me",
  RejectionReason.notInMood => "Not feeling it today",
  RejectionReason.other => 'Something else',
};
