import 'package:flutter/material.dart';

import 'forge_tag.dart';

/// The four subtle authority states spec section 16 asks for — deliberately
/// just four, reused everywhere an authority indicator is needed (active
/// mission, XP reward, competition score/rank) rather than a bespoke
/// widget per screen. Built on the existing [ForgeTag] rather than a new
/// visual language, matching "do not clutter every screen."
enum AuthorityIndicator { pendingSync, provisional, confirmed, conflict }

/// A small, reusable badge — the one place a screen renders "is this
/// provisional or confirmed" (spec section 16). Callers map their own
/// domain status (`MissionSyncStatus`, `CompetitionAuthorityStatus`,
/// etc.) to one of the four [AuthorityIndicator] values; this widget
/// never reaches into backend state itself.
class AuthorityStatusBadge extends StatelessWidget {
  const AuthorityStatusBadge({super.key, required this.indicator});

  final AuthorityIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (indicator) {
      AuthorityIndicator.pendingSync => ('Syncing…', ForgeTagVariant.neutral),
      AuthorityIndicator.provisional => (
        'Provisional',
        ForgeTagVariant.outline,
      ),
      AuthorityIndicator.confirmed => ('Confirmed', ForgeTagVariant.accent),
      AuthorityIndicator.conflict => (
        'Needs attention',
        ForgeTagVariant.accent2,
      ),
    };
    return Semantics(
      label: 'Sync status: $label',
      child: ExcludeSemantics(
        child: ForgeTag(label: label, variant: variant),
      ),
    );
  }
}
