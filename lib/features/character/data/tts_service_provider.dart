import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/tts_service.dart';
import 'services/flutter_tts_service.dart';

/// A single long-lived [TtsService] for the whole app (not autoDispose) —
/// the underlying plugin engine is expensive to recreate. Overridden with
/// `FakeTtsService` in every test.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = FlutterTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});
