// Roadmap Item 13B step 3/4 — attempted real sign-in through the actual
// Flutter app widget tree (ForgeApp -> SignInPage), against the live
// staging Supabase project.
//
// Status: blocked, documented rather than faked. `supa.Supabase.initialize`
// hangs indefinitely under `flutter test`'s VM test binding — it never
// completes even with `HttpOverrides.global = null` set to allow real
// network — most likely because its local-session-storage setup depends
// on a platform channel (shared_preferences/path_provider) that plain
// `flutter test` doesn't service. Confirmed independently reproducible:
// the test times out (30s) before even reaching the first
// `tester.pumpWidget`-driven frame that would show `SignInPage`.
//
// This is the second, independent obstacle (distinct from the headless
// browser's inability to produce Flutter Web's required trusted click —
// see this session's Item 13 report) to literally driving pixels/widgets
// for auth in this environment. The equivalent real behavior — real
// GoTrue sign-in, session, sign-out, sign-back-in — IS independently
// verified, just via the real production adapter classes directly rather
// than through this widget tree: see
// staging_live_adapter_test.dart's "real Supabase Auth flow" group, which
// passes against the same live staging project with the same synthetic
// user.
//
// Not resolved in this pass — resolving it (e.g. providing a
// platform-channel-free `LocalStorage` implementation to
// `Supabase.initialize` for tests, or running via `integration_test` on a
// real device/emulator instead of plain `flutter test`) is future work,
// not attempted here to avoid broadening this pass's scope further.
@Tags(['live_staging'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real sign-in through the actual SignInPage widget tree — blocked by '
    'Supabase.initialize hanging under flutter test\'s VM binding; see '
    'this file\'s header. Equivalent real-adapter coverage exists in '
    'staging_live_adapter_test.dart.',
    () {},
    skip: true,
  );
}
