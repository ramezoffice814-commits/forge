import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/social/domain/entities/profile_visibility_settings.dart';
import 'package:forge/features/social/domain/enums/profile_visibility.dart';
import 'package:forge/features/social/presentation/pages/public_profile_page.dart';
import 'package:forge/features/social/presentation/providers/social_providers.dart';

import '../../../support/fake_auth_overrides.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 9);

  Widget wrap(String userId) {
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        socialClockProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: PublicProfilePage(userId: userId),
      ),
    );
  }

  testWidgets('shows a loading state on the first frame', (tester) async {
    await tester.pumpWidget(wrap('mock-social-0'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders a public mock profile once loaded', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        socialClockProvider.overrideWithValue(() => fixedNow),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(socialRepositoryProvider)
        .setVisibilitySettings(
          ProfileVisibilitySettings(
            userId: 'mock-social-0',
            visibility: ProfileVisibility.public,
            updatedAt: fixedNow,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const PublicProfilePage(userId: 'mock-social-0'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aiko'), findsOneWidget);
    expect(find.text('Steady Hand'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
  });

  testWidgets('shows a neutral hidden message for a friends-only stranger '
      'profile, never an error', (tester) async {
    await tester.pumpWidget(wrap('mock-social-0'));
    await tester.pumpAndSettle();

    expect(find.text('This profile is private'), findsOneWidget);
    expect(find.textContaining("Couldn't load"), findsNothing);
  });

  testWidgets('the current user can always view their own profile', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        socialClockProvider.overrideWithValue(() => fixedNow),
      ],
    );
    addTearDown(container.dispose);
    final ownUserId = container.read(currentSocialUserIdProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: PublicProfilePage(userId: ownUserId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This profile is private'), findsNothing);
    expect(find.text('Level'), findsOneWidget);
  });
}
