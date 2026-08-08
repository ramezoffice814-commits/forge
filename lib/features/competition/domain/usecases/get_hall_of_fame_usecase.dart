import '../entities/hall_of_fame_record.dart';
import '../repositories/competition_repository.dart';

/// Historical records only — never consulted by ranking (spec section 22).
class GetHallOfFameUseCase {
  const GetHallOfFameUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<List<HallOfFameRecord>> call() => _repository.getHallOfFame();
}
