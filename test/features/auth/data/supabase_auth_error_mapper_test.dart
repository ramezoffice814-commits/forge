import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/data/supabase/supabase_auth_error_mapper.dart';
import 'package:forge/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

void main() {
  test('maps AuthWeakPasswordException to WeakPasswordFailure', () {
    final error = supa.AuthWeakPasswordException(
      message: 'weak',
      statusCode: '422',
      reasons: const ['length'],
    );
    expect(mapSupabaseAuthError(error), isA<WeakPasswordFailure>());
  });

  test('maps AuthRetryableFetchException to NetworkFailure', () {
    final error = supa.AuthRetryableFetchException();
    expect(mapSupabaseAuthError(error), isA<NetworkFailure>());
  });

  test('maps AuthSessionMissingException to NotAuthenticatedFailure', () {
    final error = supa.AuthSessionMissingException();
    expect(mapSupabaseAuthError(error), isA<NotAuthenticatedFailure>());
  });

  test('maps email_exists code to EmailAlreadyInUseFailure', () {
    final error = const supa.AuthApiException('exists', code: 'email_exists');
    expect(mapSupabaseAuthError(error), isA<EmailAlreadyInUseFailure>());
  });

  test('maps user_already_exists code to EmailAlreadyInUseFailure', () {
    final error = const supa.AuthApiException(
      'exists',
      code: 'user_already_exists',
    );
    expect(mapSupabaseAuthError(error), isA<EmailAlreadyInUseFailure>());
  });

  test(
    'maps an unstructured 400 (typical wrong-password response) to InvalidCredentialsFailure',
    () {
      final error = const supa.AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
      );
      expect(mapSupabaseAuthError(error), isA<InvalidCredentialsFailure>());
    },
  );

  test('maps an unrecognized AuthApiException to UnknownAuthFailure', () {
    final error = const supa.AuthApiException('mystery', statusCode: '500');
    expect(mapSupabaseAuthError(error), isA<UnknownAuthFailure>());
  });

  test('maps a non-auth error to UnknownAuthFailure', () {
    expect(mapSupabaseAuthError(Exception('boom')), isA<UnknownAuthFailure>());
  });
}
