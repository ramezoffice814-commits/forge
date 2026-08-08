import '../entities/user_title.dart';
import '../events/progression_event.dart';
import '../policies/title_policy.dart';
import '../repositories/progression_repository.dart';
import '../services/mission_history_snapshot_builder.dart';

/// Title evaluation, kept separate from XP (see `TitlePolicy`). Records a
/// `TitleUnlocked` event only when the resolved title actually changes from
/// the last one recorded — repeated calls with unchanged behavior are a
/// no-op on the event log.
class GetTitlesUseCase {
  const GetTitlesUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<UserTitle> call(String userId, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final snapshot = MissionHistorySnapshotBuilder.build(
      _repository.completionsForUser(userId),
      asOf: effectiveNow,
    );
    final titles = _repository.getTitleDefinitions();
    final fallback = ([
      ...titles,
    ]..sort((a, b) => a.priority.compareTo(b.priority))).first;

    final title = TitlePolicy.evaluate(
      snapshot: snapshot,
      catalog: titles,
      fallback: fallback,
      reasonFor: (def) => def.description,
    );

    final titleEvents = _repository
        .eventsForUser(userId)
        .whereType<TitleUnlocked>()
        .toList();
    final lastTitleId = titleEvents.isEmpty ? null : titleEvents.last.titleId;

    if (lastTitleId != title.id) {
      await _repository.appendEvent(
        TitleUnlocked(
          eventId: '${title.id}-unlock-${effectiveNow.microsecondsSinceEpoch}',
          userId: userId,
          occurredAt: effectiveNow,
          sequenceNumber: 0,
          titleId: title.id,
        ),
      );
    }

    return title;
  }
}
