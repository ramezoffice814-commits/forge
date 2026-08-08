import 'package:flutter/foundation.dart';

import '../../domain/entities/hall_of_fame_record.dart';
import '../../domain/usecases/get_current_competition_state_usecase.dart';
import '../../domain/usecases/get_season_progress_usecase.dart';

@immutable
sealed class CompetitionState {
  const CompetitionState();
}

class CompetitionLoading extends CompetitionState {
  const CompetitionLoading();
}

class CompetitionError extends CompetitionState {
  const CompetitionError(this.message);

  final String message;
}

class CompetitionReady extends CompetitionState {
  const CompetitionReady({
    required this.current,
    required this.hallOfFame,
    required this.seasonProgress,
  });

  final CurrentCompetitionState current;
  final List<HallOfFameRecord> hallOfFame;
  final SeasonProgressSnapshot seasonProgress;
}
