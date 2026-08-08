import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// Reusable "Why this mission?" expandable — reads only the engine's
/// already-sanitized [reasons] strings, never raw weights or history.
/// Shared by the Dashboard mission card and the mission detail screen.
class MissionExplanationPanel extends StatefulWidget {
  const MissionExplanationPanel({
    super.key,
    required this.reasons,
    this.initiallyExpanded = false,
  });

  final List<String> reasons;
  final bool initiallyExpanded;

  @override
  State<MissionExplanationPanel> createState() =>
      _MissionExplanationPanelState();
}

class _MissionExplanationPanelState extends State<MissionExplanationPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final visibleReasons = widget.reasons.take(3).toList();
    if (visibleReasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: tokens.radius.mdRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.space1),
            child: Semantics(
              button: true,
              label: _expanded
                  ? 'Hide why this mission was chosen'
                  : 'Why this mission?',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Why this mission?',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: tokens.accent),
                  ),
                  SizedBox(width: tokens.spacing.space1),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: tokens.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in visibleReasons)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.space1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: TextStyle(
                            color: tokens.text.withValues(alpha: 0.6),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
