import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart' as plugin;

import '../../domain/services/tts_service.dart';

/// Wraps the `flutter_tts` plugin (system voices only — no cloud TTS, no
/// voice cloning). Every method swallows platform errors rather than
/// throwing: a missing engine or unsupported platform must degrade to
/// "subtitles only," never block the mission flow.
class FlutterTtsService implements TtsService {
  FlutterTtsService({plugin.FlutterTts? tts})
    : _tts = tts ?? plugin.FlutterTts();

  final plugin.FlutterTts _tts;

  bool _available = false;
  TtsPlaybackState _state = TtsPlaybackState.stopped;
  Completer<void>? _pending;

  static const _safetyTimeout = Duration(seconds: 30);

  @override
  bool get isAvailable => _available;

  @override
  TtsPlaybackState get state => _state;

  @override
  Future<void> initialize() async {
    try {
      _tts.setStartHandler(() => _state = TtsPlaybackState.speaking);
      _tts.setCompletionHandler(() {
        _state = TtsPlaybackState.stopped;
        _resolvePending();
      });
      _tts.setCancelHandler(() {
        _state = TtsPlaybackState.stopped;
        _resolvePending();
      });
      _tts.setErrorHandler((dynamic _) {
        _state = TtsPlaybackState.stopped;
        _resolvePending();
      });
      await _tts.awaitSpeakCompletion(true);
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_available) return;

    _resolvePending();
    final completer = Completer<void>();
    _pending = completer;
    _state = TtsPlaybackState.speaking;

    unawaited(
      Future<void>.delayed(_safetyTimeout, () {
        if (identical(_pending, completer)) _resolvePending();
      }),
    );

    try {
      await _tts.speak(text);
    } catch (_) {
      _resolvePending();
      return;
    }
    return completer.future;
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to fall back to — treat as already stopped.
    }
    _state = TtsPlaybackState.stopped;
    _resolvePending();
  }

  @override
  Future<void> setVolume(double volume) =>
      _guarded(() => _tts.setVolume(volume));

  @override
  Future<void> setRate(double rate) => _guarded(() => _tts.setSpeechRate(rate));

  @override
  Future<void> setPitch(double pitch) => _guarded(() => _tts.setPitch(pitch));

  @override
  Future<void> dispose() async {
    _resolvePending();
    await stop();
  }

  void _resolvePending() {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _guarded(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Best-effort only — voice tuning must never block the flow.
    }
  }
}
