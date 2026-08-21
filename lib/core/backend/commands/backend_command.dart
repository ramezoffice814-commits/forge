import 'package:flutter/foundation.dart';

/// The shared shape every backend command carries — deliberately minimal
/// and never extended with a computed/reward field. See the module's
/// trust-boundary rule: a command is a *request*, never an *authorization*
/// (`core/security/trust_boundary.dart`). Nothing here can carry XP,
/// level, achievement, rank, or league data — those only ever appear in a
/// *response*, never a command.
@immutable
abstract class BackendCommand {
  const BackendCommand({
    required this.commandId,
    required this.missionInstanceId,
    required this.userId,
    required this.timestamp,
    required this.sequence,
    required this.idempotencyKey,
  });

  /// Unique per attempt — see [RequestIdGenerator]. Two retries of the
  /// same logical command have different [commandId]s but the same
  /// [idempotencyKey].
  final String commandId;

  final String missionInstanceId;

  /// Always derived from the authenticated session
  /// ([AuthenticatedBackendClient]), never taken from arbitrary user
  /// input — a command's [userId] is context-derived identity, not a
  /// free-form field.
  final String userId;

  final DateTime timestamp;

  /// Monotonically increasing per [missionInstanceId] — the input
  /// out-of-order/stale-sequence rejection is built from (see
  /// `IdempotencyReplayGuard`).
  final int sequence;

  /// Identifies "this exact logical operation," stable across retries —
  /// see [IdempotencyKeyGenerator].
  final String idempotencyKey;

  /// Every reward-shaped field name a command's opaque payload map must
  /// never contain — checked at construction time by
  /// [assertNoForbiddenFields], not just documented.
  static const List<String> forbiddenClientFields = [
    'xp',
    'xpReward',
    'level',
    'competitiveScore',
    'rank',
    'leaguePlacement',
    'achievementUnlocked',
    'seasonReward',
  ];

  /// Actively enforces the rule (spec section 3: "do not allow arbitrary
  /// XP, competitive score, level, rank, achievement unlock or league
  /// placement fields in client commands") — called from every command
  /// that carries an opaque payload map ([RecordMissionProgressCommand],
  /// [SubmitMissionCommand]). Throws rather than silently stripping the
  /// field, so a client bug that tries to smuggle a reward value fails
  /// loudly and immediately, not silently server-side.
  static void assertNoForbiddenFields(Map<String, Object?> payload) {
    final found = payload.keys.where(forbiddenClientFields.contains).toList();
    if (found.isNotEmpty) {
      throw ArgumentError(
        'Command payload contains forbidden reward-shaped field(s): '
        '${found.join(', ')} — XP, level, competitive score, rank, '
        'achievement unlocks, and league placement are server-calculated '
        'outputs, never client-supplied input.',
      );
    }
  }
}
