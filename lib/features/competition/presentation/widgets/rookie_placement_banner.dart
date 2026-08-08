import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../domain/entities/rookie_status.dart';

/// Shown only while [RookieStatus.isRookie] is true. Copy is deliberately
/// neutral-to-encouraging — spec section 28 explicitly forbids anything
/// like "beginner" framed as a deficiency.
class RookiePlacementBanner extends StatelessWidget {
  const RookiePlacementBanner({super.key, required this.status});

  final RookieStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ForgeCard(
      elevation: ForgeCardElevation.sm,
      children: [
        Text('Placement Period', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space1),
        Text(
          "You're currently matched with newer participants while your "
          'starting league is determined by your own performance — your '
          'account age never affects it.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
