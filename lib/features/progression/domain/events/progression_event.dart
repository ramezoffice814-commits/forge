import 'package:flutter/foundation.dart';

import '../entities/xp_reward_evaluation.dart';

enum ProgressionEventType {
  xpPreviewCalculated,
  levelReached,
  achievementUnlocked,
  titleUnlocked,
}

/// Progression's own event log, mirroring the mission module's philosophy:
/// state is derived by folding these, never mutated directly. There is
/// deliberately no `XpGranted` event type — see the module's trust-boundary
/// notes; every XP fact here is named to make its non-authoritative status
/// obvious at the call site.
@immutable
sealed class ProgressionEvent {
  const ProgressionEvent({
    required this.eventId,
    required this.userId,
    required this.occurredAt,
    required this.sequenceNumber,
  });

  final String eventId;
  final String userId;
  final DateTime occurredAt;
  final int sequenceNumber;

  ProgressionEventType get type;

  ProgressionEvent withSequenceNumber(int sequenceNumber);
}

/// A mission's XP was evaluated — always provisional (see
/// `XpRewardEvaluation.provisionalOnly`).
final class XpPreviewCalculated extends ProgressionEvent {
  const XpPreviewCalculated({
    required super.eventId,
    required super.userId,
    required super.occurredAt,
    required super.sequenceNumber,
    required this.evaluation,
  });

  final XpRewardEvaluation evaluation;

  @override
  ProgressionEventType get type => ProgressionEventType.xpPreviewCalculated;

  @override
  XpPreviewCalculated withSequenceNumber(int sequenceNumber) =>
      XpPreviewCalculated(
        eventId: eventId,
        userId: userId,
        occurredAt: occurredAt,
        sequenceNumber: sequenceNumber,
        evaluation: evaluation,
      );
}

final class LevelReached extends ProgressionEvent {
  const LevelReached({
    required super.eventId,
    required super.userId,
    required super.occurredAt,
    required super.sequenceNumber,
    required this.levelNumber,
  });

  final int levelNumber;

  @override
  ProgressionEventType get type => ProgressionEventType.levelReached;

  @override
  LevelReached withSequenceNumber(int sequenceNumber) => LevelReached(
    eventId: eventId,
    userId: userId,
    occurredAt: occurredAt,
    sequenceNumber: sequenceNumber,
    levelNumber: levelNumber,
  );
}

final class AchievementUnlocked extends ProgressionEvent {
  const AchievementUnlocked({
    required super.eventId,
    required super.userId,
    required super.occurredAt,
    required super.sequenceNumber,
    required this.achievementId,
  });

  final String achievementId;

  @override
  ProgressionEventType get type => ProgressionEventType.achievementUnlocked;

  @override
  AchievementUnlocked withSequenceNumber(int sequenceNumber) =>
      AchievementUnlocked(
        eventId: eventId,
        userId: userId,
        occurredAt: occurredAt,
        sequenceNumber: sequenceNumber,
        achievementId: achievementId,
      );
}

final class TitleUnlocked extends ProgressionEvent {
  const TitleUnlocked({
    required super.eventId,
    required super.userId,
    required super.occurredAt,
    required super.sequenceNumber,
    required this.titleId,
  });

  final String titleId;

  @override
  ProgressionEventType get type => ProgressionEventType.titleUnlocked;

  @override
  TitleUnlocked withSequenceNumber(int sequenceNumber) => TitleUnlocked(
    eventId: eventId,
    userId: userId,
    occurredAt: occurredAt,
    sequenceNumber: sequenceNumber,
    titleId: titleId,
  );
}
