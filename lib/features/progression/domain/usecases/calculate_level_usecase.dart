import 'package:flutter/foundation.dart';

import '../entities/level_definition.dart';
import '../events/progression_event.dart';
import '../policies/level_policy.dart';
import '../repositories/progression_repository.dart';

@immutable
class LevelCalculationResult {
  const LevelCalculationResult({
    required this.current,
    required this.next,
    required this.progress,
    required this.justLeveledUp,
  });

  final LevelDefinition current;
  final LevelDefinition? next;
  final double progress;

  /// True exactly once per level crossing — the signal
  /// `LevelUpCelebration` listens for. A repeated call against the same
  /// state never reports this true twice (see the `LevelReached` audit
  /// check below).
  final bool justLeveledUp;
}

/// Deterministic level lookup, plus the one place a `LevelReached` event is
/// recorded the first time a level is actually crossed.
class CalculateLevelUseCase {
  const CalculateLevelUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<LevelCalculationResult> call(String userId, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final levels = _repository.getLevels();
    final events = _repository.eventsForUser(userId);

    final totalXp = events.whereType<XpPreviewCalculated>().fold(
      0,
      (sum, e) => sum + e.evaluation.finalXpPreview,
    );

    final current = LevelPolicy.levelFor(totalXp, levels);
    final next = LevelPolicy.nextLevel(current, levels);
    final progress = LevelPolicy.progressToNextLevel(totalXp, levels);

    final lastRecordedLevel = events.whereType<LevelReached>().fold(
      1,
      (max, e) => e.levelNumber > max ? e.levelNumber : max,
    );

    final justLeveledUp = current.levelNumber > lastRecordedLevel;
    if (justLeveledUp) {
      await _repository.appendEvent(
        LevelReached(
          eventId:
              'level-${current.levelNumber}-${effectiveNow.microsecondsSinceEpoch}',
          userId: userId,
          occurredAt: effectiveNow,
          sequenceNumber: 0,
          levelNumber: current.levelNumber,
        ),
      );
    }

    return LevelCalculationResult(
      current: current,
      next: next,
      progress: progress,
      justLeveledUp: justLeveledUp,
    );
  }
}
