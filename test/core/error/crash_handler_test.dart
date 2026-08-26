import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/error/crash_handler.dart';

void main() {
  test('logCrash never throws for a plain error/stack pair', () {
    expect(
      () => logCrash(Exception('boom'), StackTrace.current, source: 'test'),
      returnsNormally,
    );
  });

  test('installCrashHandlers wires FlutterError.onError without dropping '
      "the framework's own presentation", () {
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);

    installCrashHandlers();

    expect(FlutterError.onError, isNotNull);
    expect(FlutterError.onError, isNot(same(original)));
  });

  test('installCrashHandlers wires PlatformDispatcher.instance.onError, '
      'and it reports the error handled (returns true) rather than '
      'letting the engine terminate the app', () {
    final original = PlatformDispatcher.instance.onError;
    addTearDown(() => PlatformDispatcher.instance.onError = original);

    installCrashHandlers();

    final handler = PlatformDispatcher.instance.onError;
    expect(handler, isNotNull);
    expect(handler!(Exception('boom'), StackTrace.current), isTrue);
  });

  test('a FlutterError routed through the installed onError does not '
      'throw and still reaches the previous handler', () {
    var previousHandlerCalled = false;
    FlutterError.onError = (details) => previousHandlerCalled = true;
    addTearDown(() => FlutterError.onError = null);

    installCrashHandlers();

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('widget build failed')),
      ),
      returnsNormally,
    );
    expect(previousHandlerCalled, isTrue);
  });
}
