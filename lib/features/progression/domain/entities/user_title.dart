import 'package:flutter/foundation.dart';

import 'mission_history_snapshot.dart';

/// A behavior-earned cosmetic title — deliberately separate from
/// [LevelDefinition]'s rank name (`TitlePolicy` never consults XP directly;
/// see its own doc comment). Titles are motivational, never punitive: there
/// is no "The Inconsistent" or "The Lazy" — only forward-framed ones.
@immutable
class UserTitleDefinition {
  const UserTitleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.matches,
  });

  final String id;
  final String name;
  final String description;

  /// Higher priority wins when several titles' criteria are simultaneously
  /// met — see `TitlePolicy.evaluate`. Kept on the catalog entry (not
  /// computed) so ordering is explicit and easy to review.
  final int priority;

  /// A pure predicate over the shared snapshot — deterministic and
  /// side-effect-free, same as every other progression criterion.
  final bool Function(MissionHistorySnapshot snapshot) matches;
}

/// The resolved title actually shown to the user, carrying *why* it was
/// earned — never just the bare name.
@immutable
class UserTitle {
  const UserTitle({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockReason,
  });

  final String id;
  final String name;
  final String description;
  final String unlockReason;
}
