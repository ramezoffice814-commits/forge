import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/shared/widgets/forge_button.dart';
import 'package:forge/shared/widgets/forge_empty_state.dart';
import 'package:forge/shared/widgets/forge_error_state.dart';
import 'package:forge/shared/widgets/forge_loading_state.dart';
import 'package:forge/shared/widgets/forge_offline_state.dart';
import 'package:forge/shared/widgets/forge_retry_state.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('ForgeLoadingState shows a spinner and optional message', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ForgeLoadingState(message: 'Loading missions…')),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading missions…'), findsOneWidget);
  });

  testWidgets('ForgeEmptyState shows title, message, and a custom action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ForgeEmptyState(
          title: 'Nothing here yet',
          message: 'Come back later.',
          action: ForgeButton(label: 'Refresh', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Come back later.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    expect(tapped, isTrue);
  });

  testWidgets('ForgeErrorState shows the message and invokes retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        ForgeErrorState(
          message: 'Failed to load.',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Failed to load.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('ForgeErrorState omits the retry action when none is given', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ForgeErrorState()));
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('ForgeOfflineState shows default copy and invokes retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(ForgeOfflineState(onRetry: () => retried = true)),
    );

    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('ForgeRetryState always shows a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(ForgeRetryState(onRetry: () => retried = true)),
    );

    expect(find.text("Couldn't load this"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
