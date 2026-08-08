import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/transmission_repository.dart';
import 'mock/mock_transmission_repository.dart';

export 'mock/mock_transmission_repository.dart' show TransmissionMockScenario;

/// Which canned scenario [MockTransmissionRepository] serves — overridden in
/// tests to reach every transmission state deterministically. There is no
/// live repository yet (out of scope for this phase).
final transmissionMockScenarioProvider = Provider<TransmissionMockScenario>((
  ref,
) {
  return TransmissionMockScenario.normalActive;
});

final transmissionRepositoryProvider = Provider<TransmissionRepository>((ref) {
  return MockTransmissionRepository(
    scenario: ref.watch(transmissionMockScenarioProvider),
  );
});
