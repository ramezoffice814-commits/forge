import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Secondary-weight shortcuts to the other tabs — deliberately smaller and
/// less prominent than the mission card, and not a duplicate of the
/// bottom nav (same destinations, but framed as "jump to X from here"
/// rather than persistent tab chrome). There's no History tab/route in
/// the approved router yet, so no History action is included here.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final action in actions)
          _QuickActionButton(action: action, tokens: tokens),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.tokens});

  final QuickAction action;
  final ForgeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: tokens.radius.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.space2,
              vertical: tokens.spacing.space2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: tokens.radius.mdRadius,
                    border: Border.all(color: tokens.divider),
                  ),
                  child: Icon(
                    action.icon,
                    color: tokens.accentRamp.c300,
                    size: 20,
                  ),
                ),
                SizedBox(height: tokens.spacing.space1),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.text.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
