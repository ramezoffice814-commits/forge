import 'package:flutter/foundation.dart';

import '../enums/competition_integrity_state.dart';
import '../enums/integrity_signal.dart';

/// An anti-abuse verdict for one completion or one user-week. UI copy
/// derived from [state] must stay neutral ("some activity is pending
/// verification") — never accusatory, and never naming the specific
/// [signals] to the user.
@immutable
class CompetitionIntegrityEvaluation {
  const CompetitionIntegrityEvaluation({
    required this.subjectId,
    required this.signals,
    required this.state,
    required this.evaluatedAt,
  });

  final String subjectId;
  final Set<IntegritySignal> signals;
  final CompetitionIntegrityState state;
  final DateTime evaluatedAt;

  bool get isClean => state == CompetitionIntegrityState.clean;
}
