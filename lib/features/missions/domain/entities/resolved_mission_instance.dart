import 'package:flutter/foundation.dart';

import '../enums/mission_instance_authority.dart';
import 'mission_instance.dart';

/// The one thing Dashboard, Daily Transmission, ActiveMissionPage, and
/// [MissionBackendSyncController]-driven backend commands must all read
/// from (Roadmap Item 13C) — a [MissionInstance] paired with an explicit
/// statement of whether its [MissionInstance.instanceId] is safe to submit
/// against as a server identity. Replaces reading `missionInstanceProvider`
/// directly wherever a caller cares about backend commands or cross-screen
/// consistency with the authoritative server mission; `missionInstanceProvider`
/// itself is unchanged and still the mock-mode/local building block this
/// wraps.
@immutable
class ResolvedMissionInstance {
  const ResolvedMissionInstance({
    required this.instance,
    required this.authority,
    this.reconciledToDifferentMission = false,
  });

  final MissionInstance instance;
  final MissionInstanceAuthority authority;

  /// True only when live/staging assignment returned a
  /// `missionDefinitionId` different from the one locally requested (spec
  /// section 9, outcome B) — [instance] reflects the server's real
  /// assigned mission in this case, never the locally-requested one, so a
  /// screen can surface "your mission for today was already set" rather
  /// than silently showing facts for a mission the user isn't actually on.
  final bool reconciledToDifferentMission;
}
