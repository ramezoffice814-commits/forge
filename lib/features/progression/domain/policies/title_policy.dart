import '../entities/mission_history_snapshot.dart';
import '../entities/user_title.dart';

/// Title evaluation is deliberately kept separate from XP — a title never
/// depends on level or XP, only on behavior patterns in the snapshot (spec
/// section 8: "title evaluation separated from XP calculation").
abstract final class TitlePolicy {
  /// The highest-[UserTitleDefinition.priority] definition whose [matches]
  /// predicate is true, or [fallback] if none match. Ties broken by catalog
  /// order (stable sort), so results stay deterministic for identical input.
  static UserTitle evaluate({
    required MissionHistorySnapshot snapshot,
    required List<UserTitleDefinition> catalog,
    required UserTitleDefinition fallback,
    required String Function(UserTitleDefinition) reasonFor,
  }) {
    final matching = catalog.where((def) => def.matches(snapshot)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final winner = matching.isEmpty ? fallback : matching.first;
    return UserTitle(
      id: winner.id,
      name: winner.name,
      description: winner.description,
      unlockReason: reasonFor(winner),
    );
  }
}
