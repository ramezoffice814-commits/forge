import 'mission_definition.dart';

/// Absolute ceiling the catalog can never exceed, regardless of what a
/// catalog entry declares — the last line of defense against a malformed
/// or (later) tampered entry. See spec: "no unbounded exercise duration".
const kMissionAbsoluteMaxMinutes = 90;

/// Validates a [MissionDefinition] against structural and safety bounds
/// *before* it ever reaches the selection engine. A catalog entry that
/// fails validation is dropped entirely — it never "mostly" participates.
abstract final class MissionCatalogValidator {
  /// Empty result means the entry is valid.
  static List<String> validate(MissionDefinition mission) {
    final errors = <String>[];

    if (mission.id.trim().isEmpty) errors.add('id must not be empty');
    if (mission.version < 1) errors.add('version must be >= 1');
    if (mission.title.trim().isEmpty) errors.add('title must not be empty');
    if (mission.description.trim().isEmpty) {
      errors.add('description must not be empty');
    }

    if (mission.minimumMinutes <= 0) {
      errors.add('minimumMinutes must be > 0');
    }
    if (mission.maximumMinutes < mission.minimumMinutes) {
      errors.add('maximumMinutes must be >= minimumMinutes');
    }
    if (mission.estimatedMinutes < mission.minimumMinutes ||
        mission.estimatedMinutes > mission.maximumMinutes) {
      errors.add(
        'estimatedMinutes must fall within [minimumMinutes, maximumMinutes]',
      );
    }
    if (mission.maximumMinutes > kMissionAbsoluteMaxMinutes) {
      errors.add(
        'maximumMinutes exceeds the absolute cap ($kMissionAbsoluteMaxMinutes)',
      );
    }

    if (mission.minimumDifficulty.index > mission.maximumDifficulty.index) {
      errors.add('minimumDifficulty must be <= maximumDifficulty');
    }
    if (mission.baseDifficulty.index < mission.minimumDifficulty.index ||
        mission.baseDifficulty.index > mission.maximumDifficulty.index) {
      errors.add(
        'baseDifficulty must fall within [minimumDifficulty, maximumDifficulty]',
      );
    }

    if (mission.baseXpHint < 0) errors.add('baseXpHint must be >= 0');
    if (mission.repeatCooldownDays < 0) {
      errors.add('repeatCooldownDays must be >= 0');
    }
    if (mission.maximumOccurrencesPerWeek < 1 ||
        mission.maximumOccurrencesPerWeek > 7) {
      errors.add('maximumOccurrencesPerWeek must be within [1, 7]');
    }

    if (mission.completionConditions.isEmpty) {
      errors.add('completionConditions must not be empty');
    } else if (mission.completionConditions.any((c) => c.trim().isEmpty)) {
      errors.add('completionConditions must not contain blank entries');
    }

    return errors;
  }

  static bool isValid(MissionDefinition mission) => validate(mission).isEmpty;
}
