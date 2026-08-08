import 'dart:async';

import '../../domain/services/tts_service.dart';

/// A controllable [TtsService] double for tests (and for exercising the
/// "TTS unavailable" degraded path in dev without a real engine). By
/// default it auto-completes each [speak] call on the next microtask;
/// set [autoComplete] to false to drive completion manually via
/// [completeCurrentSpeech] — needed to test races like rapid replay/skip
/// while speech is still "in flight".
class FakeTtsService implements TtsService {
  FakeTtsService({this.simulateUnavailable = false, this.autoComplete = true});

  final bool simulateUnavailable;
  bool autoComplete;

  bool _available = false;
  TtsPlaybackState _state = TtsPlaybackState.stopped;
  Completer<void>? _pending;
  bool disposed = false;

  final List<String> spokenTexts = [];
  int stopCalls = 0;
  double? lastVolume;
  double? lastRate;
  double? lastPitch;

  @override
  bool get isAvailable => _available;

  @override
  TtsPlaybackState get state => _state;

  @override
  Future<void> initialize() async {
    _available = !simulateUnavailable;
  }

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    if (!_available) return;

    _resolvePending();
    final completer = Completer<void>();
    _pending = completer;
    _state = TtsPlaybackState.speaking;

    if (autoComplete) {
      scheduleMicrotask(completeCurrentSpeech);
    }
    return completer.future;
  }

  /// Manually resolves whatever [speak] call is currently in flight —
  /// only useful when [autoComplete] is false.
  void completeCurrentSpeech() {
    _state = TtsPlaybackState.stopped;
    _resolvePending();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _state = TtsPlaybackState.stopped;
    _resolvePending();
  }

  @override
  Future<void> setVolume(double volume) async => lastVolume = volume;

  @override
  Future<void> setRate(double rate) async => lastRate = rate;

  @override
  Future<void> setPitch(double pitch) async => lastPitch = pitch;

  @override
  Future<void> dispose() async {
    disposed = true;
    _resolvePending();
  }

  void _resolvePending() {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
