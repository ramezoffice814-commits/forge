import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import 'behavioral_history.dart';
import 'mission_definition.dart';
import 'user_discipline_profile.dart';

/// Everything the engine needs, handed in as one immutable value — no
/// hidden reads from global state, which is what keeps
/// `MissionSelectionEngine.select` a pure function of its input.
@immutable
class MissionSelectionRequest {
  const MissionSelectionRequest({
    required this.profile,
    required this.history,
    required this.currentDateTime,
    required this.catalog,
    this.requestedCategory,
    this.requestedDuration,
    this.recoveryOverride,
    this.excludedMissionIds = const {},
    this.contextSource = 'dashboard',
  });

  final UserDisciplineProfile profile;
  final BehavioralHistory history;
  final DateTime currentDateTime;
  final List<MissionDefinition> catalog;

  final MissionCategory? requestedCategory;
  final int? requestedDuration;

  /// `true`/`false` forces recovery on/off for this request; `null` lets
  /// [RecoveryMissionPolicy] decide from the profile/history.
  final bool? recoveryOverride;

  /// Missions to skip entirely this round — how a rejected mission stays
  /// rejected for the *current* selection without permanently banning it.
  final Set<String> excludedMissionIds;

  final String contextSource;
}
