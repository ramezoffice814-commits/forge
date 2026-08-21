import 'package:flutter/foundation.dart';

import '../entities/xp_reward_evaluation.dart';

enum ProgressionEventType {
  xpPreviewCalculated,
  levelReached,
  achievementUnlocked,
  titleUnlocked,
  xpConfirmedByServer,
}

/// Progression's own event log, mirroring the mission module's philosophy:
/// state is derived by folding these, never mutated directly. Every XP
/// fact here is named to make its authority status obvious at the call
/// site — [XpPreviewCalculated] is always provisional;
/// [XpConfirmedByServer] is the one and only event type
/// [ProgressionAggregate.rehydrate] treats as authoritative for
/// [UserProgressionProfile.totalConfirmedXp], and it is only ever
/// legitimate to append one after an actual `submit-mission` server
/// response (see `ProgressionController.applyServerConfirmedReward` and
/// `lib/core/backend/reconciliation/mission_command_reconciliation.dart`'s
/// `ConfirmedMissionReward` — nothing else in this app constructs one).
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

/// A mission's XP was confirmed by the server (spec section 9 — Phase
/// 10D). [confirmedTotalXp] is the server's authoritative running total
/// (`user_progression.confirmed_xp` at the time of this confirmation),
/// never a delta — `ProgressionAggregate.rehydrate` simply takes the
/// latest one it sees, so a missed intermediate confirmation is never a
/// problem. [missionInstanceId] is what lets rehydration move that
/// mission's contribution out of the provisional bucket without
/// double-counting it once confirmed.
final class XpConfirmedByServer extends ProgressionEvent {
  const XpConfirmedByServer({
    required super.eventId,
    required super.userId,
    required super.occurredAt,
    required super.sequenceNumber,
    required this.missionInstanceId,
    required this.confirmedTotalXp,
    required this.confirmedLevel,
  });

  final String missionInstanceId;
  final int confirmedTotalXp;
  final int confirmedLevel;

  @override
  ProgressionEventType get type => ProgressionEventType.xpConfirmedByServer;

  @override
  XpConfirmedByServer withSequenceNumber(int sequenceNumber) =>
      XpConfirmedByServer(
        eventId: eventId,
        userId: userId,
        occurredAt: occurredAt,
        sequenceNumber: sequenceNumber,
        missionInstanceId: missionInstanceId,
        confirmedTotalXp: confirmedTotalXp,
        confirmedLevel: confirmedLevel,
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
