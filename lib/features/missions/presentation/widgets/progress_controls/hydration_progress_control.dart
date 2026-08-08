import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import 'progress_update_callback.dart';

class HydrationProgressControl extends StatelessWidget {
  const HydrationProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final HydrationProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    void setServings(int next) {
      onUpdate(
        HydrationProgressState(
          currentServings: next,
          targetServings: state.targetServings,
        ),
        isCorrection: next < state.currentServings,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.currentServings} / ${state.targetServings} glasses',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.space2),
        Wrap(
          spacing: tokens.spacing.space1,
          runSpacing: tokens.spacing.space1,
          children: [
            for (var i = 1; i <= state.targetServings; i++)
              _GlassIcon(
                filled: i <= state.currentServings,
                onTap: enabled
                    ? () => setServings(i <= state.currentServings ? i - 1 : i)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: tokens.radius.smRadius,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space1),
        child: Icon(
          filled ? Icons.local_drink_rounded : Icons.local_drink_outlined,
          color: filled ? tokens.accent : tokens.text.withValues(alpha: 0.4),
          size: 28,
        ),
      ),
    );
  }
}
