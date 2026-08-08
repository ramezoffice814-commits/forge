import 'package:flutter/foundation.dart';

import '../enums/hall_of_fame_record_type.dart';

/// A permanent historical record — Hall of Fame is display-only and never
/// feeds back into current ranking (see module acceptance criteria).
@immutable
class HallOfFameRecord {
  const HallOfFameRecord({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.seasonId,
    required this.type,
    required this.description,
    required this.achievedAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String seasonId;
  final HallOfFameRecordType type;

  /// Precomputed display string (e.g. "Reached Obsidian League") — the
  /// widget never re-derives wording from raw values.
  final String description;

  final DateTime achievedAt;
}
