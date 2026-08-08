import 'package:flutter/foundation.dart';

/// One rung on the level ladder. Product placeholders only — deliberately
/// game-y ranks ("Builder", "Architect"), never language implying
/// real-world status, credential, or expertise.
@immutable
class LevelDefinition {
  const LevelDefinition({
    required this.levelNumber,
    required this.requiredXp,
    required this.title,
    required this.description,
    this.unlocks = const [],
    this.badgeId,
  });

  final int levelNumber;

  /// Total (confirmed or preview) XP required to *reach* this level.
  final int requiredXp;

  final String title;
  final String description;

  /// Cosmetic-only unlock labels (e.g. "New character line") — never a real
  /// reward; see the module-level trust-boundary notes.
  final List<String> unlocks;

  final String? badgeId;
}
