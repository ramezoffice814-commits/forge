import 'package:flutter/foundation.dart';

/// Display-only summary of the weekly league standing. Nothing here is
/// calculated by the client — every field is precomputed data handed down
/// by the repository (real ranking calculation is backend-only, and out of
/// scope for this phase regardless).
@immutable
class LeaguePreview {
  const LeaguePreview({
    required this.leagueName,
    required this.currentPosition,
    required this.promotionZoneDistance,
    required this.weekEndingLabel,
  });

  final String leagueName;
  final int currentPosition;

  /// Positions away from the promotion zone; `0` means already in it.
  final int promotionZoneDistance;

  /// Precomputed display string (e.g. "Ends in 3 days") — the widget never
  /// does date math itself.
  final String weekEndingLabel;
}
