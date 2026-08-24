import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';

/// The confirmed facts a real `assignDailyMission` response needs to be
/// reconstructed later offline — deliberately not the full [MissionInstance]
/// (title/description drift is fine to re-derive from the catalog; the
/// *identity* is the one thing that must never be re-generated).
class CachedMissionAssignment {
  const CachedMissionAssignment({
    required this.missionInstanceId,
    required this.missionDefinitionId,
    required this.assignedDate,
  });

  final String missionInstanceId;
  final String missionDefinitionId;
  final DateTime assignedDate;

  Map<String, Object?> toJson() => {
    'missionInstanceId': missionInstanceId,
    'missionDefinitionId': missionDefinitionId,
    'assignedDate': assignedDate.toIso8601String(),
  };

  static CachedMissionAssignment? tryFromJson(Map<String, Object?> json) {
    final instanceId = json['missionInstanceId'];
    final definitionId = json['missionDefinitionId'];
    final assignedDateRaw = json['assignedDate'];
    if (instanceId is! String ||
        definitionId is! String ||
        assignedDateRaw is! String) {
      return null;
    }
    final assignedDate = DateTime.tryParse(assignedDateRaw);
    if (assignedDate == null) return null;
    return CachedMissionAssignment(
      missionInstanceId: instanceId,
      missionDefinitionId: definitionId,
      assignedDate: assignedDate,
    );
  }
}

/// Persists the one confirmed server assignment per user per day, so a
/// user who goes offline after a successful assignment still has the
/// *authoritative* id available on relaunch — never falls back to a fresh
/// local/provisional id just because the app restarted (spec section 8:
/// "if a confirmed mission assignment was previously cached: use that
/// authoritative id offline").
class CachedMissionAssignmentStore {
  const CachedMissionAssignmentStore(this._store);

  final SecureKeyValueStore _store;

  String _keyFor(String userId, DateTime date) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return 'forge.mission_assignment.$userId.$dateKey';
  }

  Future<CachedMissionAssignment?> load(String userId, DateTime date) async {
    final raw = await _store.read(_keyFor(userId, date));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedMissionAssignment.tryFromJson(decoded.cast());
    } catch (_) {
      // Corrupt/unrecognized cache must never crash the resolution flow —
      // treated as "no cached assignment", same fallback as never having
      // cached one.
      return null;
    }
  }

  Future<void> save(String userId, CachedMissionAssignment assignment) {
    return _store.write(
      _keyFor(userId, assignment.assignedDate),
      jsonEncode(assignment.toJson()),
    );
  }
}

final cachedMissionAssignmentStoreProvider =
    Provider<CachedMissionAssignmentStore>((ref) {
      return CachedMissionAssignmentStore(
        ref.watch(secureKeyValueStoreProvider),
      );
    });
