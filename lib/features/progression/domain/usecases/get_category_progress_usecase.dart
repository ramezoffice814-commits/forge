import '../../../missions/domain/enums/mission_category.dart';
import '../entities/category_progress.dart';
import '../repositories/progression_repository.dart';

class GetCategoryProgressUseCase {
  const GetCategoryProgressUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<Map<MissionCategory, CategoryProgress>> call(String userId) {
    return _repository.getCategoryProgress(userId);
  }
}
