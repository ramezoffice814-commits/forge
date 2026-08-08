import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';

/// Shown only when `overview.recoveryModeActive` is true. Deliberately
/// calm, never guilt-based — no "you failed", "streak ruined", or similar
/// copy. Today's mission has already been adjusted to something
/// achievable (see MockDashboardRepository's recovery scenario); this
/// banner just explains that, and offers a low-pressure way to see it.
class RecoveryBanner extends StatelessWidget {
  const RecoveryBanner({super.key, required this.onViewMission});

  final VoidCallback onViewMission;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.space4),
        decoration: BoxDecoration(
          color: tokens.accentRamp.c900.withValues(alpha: 0.6),
          borderRadius: tokens.radius.lgRadius,
          border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.self_improvement_rounded, color: tokens.accentRamp.c300),
            SizedBox(width: tokens.spacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recovery Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.space1),
                  Text(
                    'Today is about rebuilding momentum. One achievable '
                    "mission is enough — we've adjusted today's mission for you.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.text.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.space3),
                  ForgeButton(
                    label: "View Today's Easier Mission",
                    variant: ForgeButtonVariant.ghost,
                    onPressed: onViewMission,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
