import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_provider.dart';
import '../domain/auth_failure.dart';
import 'auth_state.dart';
import 'auth_usecase_providers.dart';

/// Single source of truth for "is the user signed in" — the router's
/// redirect policy and every auth screen read from this, never a
/// widget-local boolean.
class AuthStateNotifier extends Notifier<AuthState> {
  StreamSubscription? _subscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.authStateChanges().listen((session) {
      state = state.copyWith(
        status: session != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        session: session,
        clearSession: session == null,
        clearFailure: true,
      );
    });
    ref.onDispose(() => _subscription?.cancel());

    _restore();
    return const AuthState(status: AuthStatus.restoring);
  }

  Future<void> _restore() async {
    try {
      final session = await ref.read(restoreSessionUseCaseProvider).call();
      state = session == null
          ? state.copyWith(
              status: AuthStatus.unauthenticated,
              clearSession: true,
            )
          : state.copyWith(
              status: AuthStatus.authenticated,
              session: session,
              clearFailure: true,
            );
    } on ForgeAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.failure, failure: e.failure);
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const UnknownAuthFailure(),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      pendingEmail: email,
      clearFailure: true,
    );
    try {
      final session = await ref
          .read(signInUseCaseProvider)
          .call(email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        clearFailure: true,
        clearPendingEmail: true,
      );
    } on ForgeAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: e.failure,
        pendingEmail: email,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const UnknownAuthFailure(),
        pendingEmail: email,
      );
    }
  }

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      pendingEmail: email,
      clearFailure: true,
    );
    try {
      final session = await ref
          .read(signUpUseCaseProvider)
          .call(displayName: displayName, email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        clearFailure: true,
        clearPendingEmail: true,
      );
    } on ForgeAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: e.failure,
        pendingEmail: email,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const UnknownAuthFailure(),
        pendingEmail: email,
      );
    }
  }

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider).call();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearSession: true,
      clearFailure: true,
      clearPendingEmail: true,
    );
  }

  /// Lets a screen dismiss a failure (e.g. on next form edit) without
  /// otherwise touching auth status.
  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }
}

final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);
