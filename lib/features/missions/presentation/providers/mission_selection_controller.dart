import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_mission_context.dart';
import '../../domain/entities/behavioral_history.dart';
import '../../domain/entities/user_discipline_profile.dart';
import '../../domain/enums/mission_category.dart';
import '../../domain/enums/mission_difficulty_level.dart';
import '../../domain/enums/rejection_reason.dart';
import '../../domain/repositories/mission_catalog_repository.dart';
import '../../domain/usecases/select_daily_mission_usecase.dart';
import 'mission_providers.dart';
import 'mission_selection_state.dart';

final selectDailyMissionUseCaseProvider = Provider((ref) {
  return SelectDailyMissionUseCase(ref.watch(missionCatalogRepositoryProvider));
});

/// The single authoritative mission-selection session for "today" — both
/// the Dashboard and the Daily Transmission read from this same provider,
/// so they can never disagree about which mission is active. Manual
/// overrides (easier mission, another category, less time, recovery,
/// reject) all funnel through here and trigger a fresh, still-deterministic
/// recomputation; none of them mutate history permanently.
class MissionSelectionController extends Notifier<MissionSelectionState> {
  late SelectDailyMissionUseCase _useCase;
  late UserDisciplineProfile _baseProfile;
  late BehavioralHistory _history;
  late DateTime _now;

  MissionCategory? _requestedCategory;
  int? _availableMinutesOverride;
  bool? _recoveryOverride;
  MissionDifficultyLevel? _intensityCapOverride;
  final Set<String> _excludedMissionIds = {};

  final Completer<void> _firstResolutionCompleter = Completer<void>();

  /// Resolves once the *first* selection (success or error) has landed.
  /// Dashboard awaits this before its own first fetch so mission data is
  /// available on Dashboard's very first render — one load, not a reactive
  /// reload-after-the-fact. Later manual overrides don't touch this; a
  /// caller that triggers one already has the fresh state as the return
  /// value of that call.
  Future<void> get ready => _firstResolutionCompleter.future;

  @override
  MissionSelectionState build() {
    _useCase = ref.watch(selectDailyMissionUseCaseProvider);
    final scenario = ref.watch(missionMockScenarioProvider);
    final context = MockMissionContexts.forScenario(scenario);
    _baseProfile = context.profile;
    _history = context.history;
    _now = context.now;
    // See DailyTransmissionController for why this must be deferred: state
    // cannot be read/written before `build()` itself has returned.
    Future.microtask(() async {
      await _recompute();
      if (!_firstResolutionCompleter.isCompleted) {
        _firstResolutionCompleter.complete();
      }
    });
    return const MissionSelectionLoading();
  }

  UserDisciplineProfile get _effectiveProfile {
    var profile = _baseProfile;
    if (_availableMinutesOverride != null) {
      profile = profile.copyWith(
        availableMinutesToday: _availableMinutesOverride,
      );
    }
    if (_intensityCapOverride != null) {
      profile = profile.copyWith(manualIntensityCap: _intensityCapOverride);
    }
    return profile;
  }

  Future<void> _recompute() async {
    state = const MissionSelectionLoading();
    try {
      final result = await _useCase(
        profile: _effectiveProfile,
        history: _history,
        currentDateTime: _now,
        requestedCategory: _requestedCategory,
        recoveryOverride: _recoveryOverride,
        excludedMissionIds: Set.of(_excludedMissionIds),
      );
      state = MissionSelectionReady(result);
    } on MissionCatalogException catch (e) {
      state = MissionSelectionError(e.message);
    } catch (_) {
      state = const MissionSelectionError(
        "Couldn't select today's mission right now.",
      );
    }
  }

  Future<void> retry() => _recompute();

  /// Caps intensity one level below whatever was just resolved and
  /// recomputes — the user, not the engine, has final say.
  Future<void> requestEasierMission() {
    final current = state;
    if (current is MissionSelectionReady) {
      _intensityCapOverride = current.result.resolvedDifficulty.oneLevelDown;
    }
    return _recompute();
  }

  Future<void> requestCategory(MissionCategory category) {
    _requestedCategory = category;
    return _recompute();
  }

  Future<void> clearCategoryRequest() {
    _requestedCategory = null;
    return _recompute();
  }

  Future<void> reduceAvailableTime(int minutes) {
    _availableMinutesOverride = minutes;
    return _recompute();
  }

  Future<void> setRecoveryMode(bool enabled) {
    _recoveryOverride = enabled;
    return _recompute();
  }

  /// One rejection nudges this session's pool away from the mission — it
  /// never bans the category and never touches persisted history.
  Future<void> rejectMission(RejectionReason reason) {
    final current = state;
    if (current is MissionSelectionReady) {
      _excludedMissionIds.add(current.result.selectedMission.id);
    }
    return _recompute();
  }
}

final missionSelectionControllerProvider =
    NotifierProvider<MissionSelectionController, MissionSelectionState>(
      MissionSelectionController.new,
    );
