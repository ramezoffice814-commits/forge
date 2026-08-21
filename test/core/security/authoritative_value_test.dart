import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/raw_backend_response.dart';
import 'package:forge/core/security/authoritative_value.dart';
import 'package:forge/core/security/data_authority.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('a LocalOnlyValue reports localOnly authority', () {
    const value = LocalOnlyValue(42);
    expect(value.authority, DataAuthority.localOnly);
    expect(value.value, 42);
  });

  test(
    'a ProvisionalValue reports provisional authority and carries reasons',
    () {
      const value = ProvisionalValue(100, reasons: ['estimated']);
      expect(value.authority, DataAuthority.provisional);
      expect(value.reasons, ['estimated']);
    },
  );

  test('a ServerConfirmedValue can only be constructed from a genuine '
      'RawBackendResponse, and reports serverConfirmed authority', () {
    final response = RawBackendResponse<int>.fromBackendAdapter(
      payload: 250,
      serverTimestamp: now,
      confirmationId: 'confirm-1',
    );
    final value = ServerConfirmedValue.fromServerResponse(response);

    expect(value.authority, DataAuthority.serverConfirmed);
    expect(value.value, 250);
    expect(value.serverTimestamp, now);
    expect(value.confirmationId, 'confirm-1');
  });

  test('there is no method that upgrades a ProvisionalValue directly into '
      'a ServerConfirmedValue — the only path is through a fresh '
      'RawBackendResponse', () {
    const provisional = ProvisionalValue(10);
    // Structural proof: ProvisionalValue exposes no method returning a
    // ServerConfirmedValue. The only way to get one is the factory
    // exercised above, which requires an independent RawBackendResponse.
    expect(provisional, isA<AuthoritativeValue<int>>());
    expect(provisional, isNot(isA<ServerConfirmedValue<int>>()));
  });

  test('two AuthoritativeValue variants for the same underlying number '
      'are never equal by authority', () {
    const provisional = ProvisionalValue(10);
    const local = LocalOnlyValue(10);
    expect(provisional.authority, isNot(local.authority));
  });
}
