import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../missions/presentation/providers/mission_selection_controller.dart';
import '../../domain/enums/ai_coach_suggested_action.dart';

/// Roadmap Item 14B section 9/12: renders confirmable chips for whichever
/// AI-suggested actions this pass actually wires to a real, existing
/// Forge use case — currently only [AiCoachSuggestedAction.requestEasierMission]
/// (Roadmap 14's spec example). Every other recognized-but-unwired action
/// is silently omitted here rather than shown as a dead button; the AI
/// itself never executes anything — this widget only ever calls into
/// [MissionSelectionController], the same deterministic use case a user
/// could already reach through ordinary Forge UI, and only after the user
/// explicitly confirms.
class SuggestedActionBar extends ConsumerWidget {
  const SuggestedActionBar({super.key, required this.actions});

  final List<AiCoachSuggestedAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!actions.contains(AiCoachSuggestedAction.requestEasierMission)) {
      return const SizedBox.shrink();
    }
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.space2),
      child: ActionChip(
        avatar: const Icon(Icons.trending_down_rounded, size: 16),
        label: const Text('Try an easier mission?'),
        onPressed: () => _confirmAndExecute(context, ref),
      ),
    );
  }

  Future<void> _confirmAndExecute(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to an easier mission?'),
        content: const Text(
          "We'll swap today's mission for something a bit lighter.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // The one and only place this ever executes: the same deterministic
    // use case the rest of Forge already exposes — never a bespoke
    // AI-only mutation path.
    await ref
        .read(missionSelectionControllerProvider.notifier)
        .requestEasierMission();
  }
}
