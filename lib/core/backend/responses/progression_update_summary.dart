import 'package:flutter/foundation.dart';

/// A minimal, server-confirmed progression delta — deliberately not the
/// full `UserProgressionProfile` shape from the progression feature; this
/// module stays decoupled from it (see Phase 10A scope: contracts only,
/// no rewiring of existing systems yet).
@immutable
class ProgressionUpdateSummary {
  const ProgressionUpdateSummary({
    required this.previousLevel,
    required this.newLevel,
    required this.confirmedTotalXp,
  });

  final int previousLevel;
  final int newLevel;
  final int confirmedTotalXp;

  bool get leveledUp => newLevel > previousLevel;
}
