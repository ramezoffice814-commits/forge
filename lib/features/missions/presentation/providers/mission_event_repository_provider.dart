import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/in_memory_mission_event_repository.dart';
import '../../domain/repositories/mission_event_repository.dart';

/// One event log for the whole app session. A plain (non-autoDispose)
/// provider, so it survives navigating away from and back to
/// `ActiveMissionPage` — losing it on every rebuild would defeat the point
/// of an event-sourced history.
final missionEventRepositoryProvider = Provider<MissionEventRepository>((ref) {
  final repository = InMemoryMissionEventRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
