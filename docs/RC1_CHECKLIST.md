# RC1 Checklist

Roadmap Item 19 ("Release Candidate & Real Platform Verification"). The
authoritative record of RC1's actual state — what was verified, what
was blocked and exactly why, and what still needs a human decision.
This is **not** a production deployment or app-store submission; it's
the honest answer to "is this build a real release candidate yet."

**Base commit**: `feature/release-candidate-rc1`, branched from
`develop @ 3864457019d25989729844c301e8671ca32c8194`. Exact commit SHA
for this checklist's own content: see the branch's final commit before
the PR was opened (`git log --oneline -1` on
`feature/release-candidate-rc1`).

**Version**: `1.0.0-rc.1+2` (see `pubspec.yaml`'s own comment for the
versioning strategy this establishes — no prior policy existed).

## RC1 gate matrix

| Area | Result | Detail |
|---|---|---|
| Android signing | BLOCKED (by design) | No production keystore exists; not generated here. Signing config is safely prepared (`android/key.properties.example`, `.gitignore` coverage confirmed both root and `android/` level, Gradle fails clearly on an incomplete `key.properties`, falls back to debug-signing only when no `key.properties` exists at all). |
| Android real-device run | BLOCKED | No Android emulator/device available in this environment (`flutter devices`/`flutter emulators`/`adb devices` all confirm none) — unchanged since Item 17/18. |
| Android notification smoke | BLOCKED | Depends on the real-device run above; not independently verifiable via SQL/API alone per this item's own instruction. |
| Windows build | BLOCKED | Developer Mode/symlink support disabled on this machine; not toggled (system-setting change requiring explicit permission). Unchanged since Item 18. |
| Windows real run | BLOCKED | Depends on the build above. |
| Web release smoke | PASS (earlier this session) / UNVERIFIED (final pass) | See "Release build results" below — a real environment blocker appeared partway through this session's final verification pass. |
| Staging live auth | BLOCKED | No real `SUPABASE_ANON_KEY`/synthetic test-user credentials available in this environment — unchanged since Item 18. |
| Staging mission flow | BLOCKED | Same credential gate. |
| Staging AI mock flow | BLOCKED | Same credential gate. |
| Staging notifications | BLOCKED | Same credential gate. |
| Staging competition | BLOCKED | Same credential gate. |
| Staging account isolation | BLOCKED | Same credential gate — though the underlying isolation guarantees are independently proven by the SQL test suite (`016_notifications.sql`, `016_least_privilege_hardening.sql`) against a real (local, not staging) Postgres. |
| Legal/privacy surfaces | PASS | Real routes now exist (`/legal/privacy`, `/legal/terms`) with honest, factual, clearly-marked draft content — not fabricated legal text, not silently claiming approval. See "Legal/privacy content" below. |
| Accessibility | PASS (targeted) | Fixed the two screens Item 18 flagged as having zero accessibility code (`ActiveMissionPage`, `ProgressPage`/`ProgressionPage`) — see "Accessibility findings" below. Not a full-app pass. |
| Crash handling | PASS | Re-verified `installCrashHandlers()` (Item 18) still wired; exercised with controlled test errors (see `test/core/error/crash_handler_test.dart`, all passing). |
| Offline/reconnect | PASS | Covered by the existing, unchanged offline/reconnect test suite (notifications, mission sync) — re-run clean this pass. |
| Release config | PASS | `assertBackendModeConfigIsSafe`/`assertAuthRepositoryConfigIsSafe` re-confirmed unchanged and correct (release+mock refused, live-without-credentials refused). |
| CI release-build coverage | PASS (added) | Three new CI jobs (`android-build`, `web-build`, `windows-build`) build each platform's release configuration on every PR — see "CI changes" below. |
| Secrets | PASS | Full secret scan clean — see "Secret scan" below. |
| Versioning | PASS | RC strategy defined and applied (`1.0.0-rc.1+2`); no prior policy existed to conflict with. |
| Package identity | PASS (audited, unchanged) | `com.forge.app.forge` (Android), Windows product naming, Web title/manifest all reviewed — none renamed (an established identity change needs explicit review, per this item's own instruction). |
| Release artifact provenance | PARTIAL | Android APK built successfully once this session (56.8MB, debug-signed, `app-release.apk`) before an environment blocker appeared — see "Release build results." |

## Android signing

**No real production keystore exists, and none was generated.** Per this
item's own instructions, generating one silently is explicitly
prohibited — this section states exactly what's needed instead:

- **Recommended keystore location**: outside this repository entirely
  (e.g. a password manager's attached-file storage, or a dedicated
  secrets vault) — never inside `F:\365_day_chalange_app`, even in a
  gitignored path, since a local accident (a misconfigured backup tool,
  a future `git add -f`) is one avoidable risk away.
- **Alias**: a descriptive, stable name — `forge-release` is used as
  the placeholder in `android/key.properties.example`; the real value
  just needs to stay consistent for the life of this app's Play Store
  listing.
- **Required passwords**: a store password and a key password (can be
  the same value, but two independent strong passwords is safer) —
  generated via `keytool -genkey -v -keystore <path> -keyalg RSA
  -keysize 2048 -validity 10000 -alias forge-release`, following
  Android's own documented flow
  (https://developer.android.com/studio/publish/app-signing).
- **`.gitignore` rules**: already in place, confirmed this pass —
  `android/key.properties` and `*.keystore`/`*.jks`/`*.p12` are
  gitignored at both the repo root (`.gitignore`) and `android/`
  (`android/.gitignore`) levels.
- **`key.properties` setup**: copy `android/key.properties.example` to
  `android/key.properties` (exact filename) and fill in the four real
  values (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) — see
  that file's own comments. Once present, `android/app/build.gradle.kts`
  automatically signs release builds with it; no other code change is
  needed. An incomplete `key.properties` fails the Gradle build
  immediately with a clear message naming the missing field (verified
  this pass with a deliberately incomplete test file, then removed).
- **Backup requirements**: this key must be backed up somewhere durable
  and access-controlled (not solely on one developer's machine) —
  **losing it means losing the ability to publish any future update to
  the same Play Store listing, permanently**; Google Play cannot accept
  a different signing key for an existing app without Play App Signing
  enrollment specifically anticipating a key reset, which has its own
  separate, non-trivial process.
- **Consequences of losing the key**: without Play App Signing's key
  upgrade path already configured in advance, a lost key means the
  existing app listing can never receive an update again — only a new
  listing under a new package name, losing all reviews/install history.

## Signing config

Prepared, verified this pass:

- `android/app/build.gradle.kts` reads `android/key.properties` if
  present, builds a real `signingConfigs.release` from it, and uses
  that for the `release` build type.
- If `key.properties` is absent entirely, the release build type falls
  back to the pre-existing debug-signing dev/CI convenience — unchanged
  behavior, not a new risk.
- If `key.properties` **exists** but is missing any of the four
  required fields, the Gradle build fails immediately with a named,
  actionable error (`check(...)` in `build.gradle.kts`) — verified by
  creating a deliberately incomplete `key.properties`, confirming the
  build failed with `"android/key.properties exists but is missing
  'keyAlias'..."`, then removing the test file.
- No secret values are committed — `android/key.properties.example` has
  placeholder text only (`REPLACE_ME`, an example path).

## Android real-device/emulator result

**BLOCKED.** `flutter devices` lists only Windows desktop and two Web
browsers; `flutter emulators` reports none configured; `adb` is not on
this machine's PATH at all. No Android emulator/device has been
available in this environment across Items 17, 18, or 19 — reported
honestly each time rather than assumed.

## Windows real verification

**BLOCKED**, unchanged reason: `flutter build windows --release` fails
immediately with "Building with plugins requires symlink support.
Please enable Developer Mode." This machine's Developer Mode was not
toggled — that's a system-setting change requiring explicit permission
this item's own instructions say not to make unprompted.

## Release build results

Three release builds were attempted this session, in this order:

1. **Android APK release** (`flutter build apk --release`) — **PASS**,
   early in this session, right after the signing-config plumbing was
   added: `app-release.apk` built successfully (56.8MB, debug-signed —
   no `key.properties` present). This confirms the current code +
   Gradle config produces a working release build.
2. Later, in this session's **final** verification pass, a fresh
   `flutter build apk --release` attempt failed with:
   `ProcessException: An Application Control policy has blocked this
   file` — Windows blocking `dartaotruntime.exe` (Flutter's AOT
   compiler binary) from running at all. Retried three times over
   ~30 seconds; failed identically each time — not a transient scan
   lock.
3. `flutter build web --release` was then attempted as a diagnostic
   (a different compiler backend) and **also failed** to compile,
   confirming this is a broader, newly-appeared environment-level
   block on Flutter's compiler toolchain on this specific machine, not
   an Android- or code-specific regression. `flutter analyze`/`flutter
   test`/`flutter doctor` all continued to work normally throughout —
   only compiled-binary invocation paths are affected.
4. Diagnostics performed (all read-only, no security settings
   touched): confirmed ample free disk space on both drives (91.5GB/
   162.1GB free), confirmed no fresh Windows Defender quarantine
   matches `dartaotruntime`/`flutter` in threat history (the only
   recent detections are unrelated, days-old entries), confirmed
   `flutter doctor` reports a healthy toolchain.
5. One further retry was attempted later in this same pass — this time
   it did not fail instantly; it ran for 47m48s before failing, a
   materially different symptom (a hang/timeout somewhere in the build,
   most plausibly network-dependent, rather than an instant policy
   block). Not retried further after this — two different failure
   modes across four attempts is itself strong evidence this machine's
   build environment is genuinely degraded right now, not something
   worth continuing to fight without touching security settings.

**Honest classification: Android APK — PASS earlier this session with
the exact code in this PR (before this environment blocker appeared),
UNVERIFIED in the final pass. Android AAB — UNVERIFIED (never
successfully attempted — the environment block appeared before this
was reached). Web — PASS earlier (Item 18's own session, and again
briefly at the start of this session before the block appeared),
UNVERIFIED in the final pass. Windows — BLOCKED (unrelated, pre-existing
Developer Mode gate).**

This is reported exactly as it happened — no result here was "turned
into PASS" that wasn't independently verified at least once with the
current code.

## Staging credential gate

**BLOCKED for all staging-dependent verification.** No real
`SUPABASE_ANON_KEY` or synthetic staging test-user password is
available anywhere in this repository or environment — confirmed
absent in `.env.example` (documentation-only, blank values) and
nowhere else in this session's context. Per this item's own
instruction, this blocks *only* staging-dependent work (sections 11-16
of the brief) — it does not block anything else, and nothing here
prints or references a real credential value.

The underlying guarantees staging verification would otherwise
re-confirm (auth, account isolation, least-privilege grants, mission
command idempotency, notification isolation) are independently proven
this session against a real local Postgres via the full SQL/Deno test
suite (17/17 + 25/25, see Full regression below) — not a substitute for
a real staging round-trip, but not nothing either.

## Legal/privacy content

New, real routes exist: `/legal/privacy` (`PrivacyPolicyPage`) and
`/legal/terms` (`TermsOfServicePage`), reachable from Settings' About
section and from any auth state (not gated behind sign-in — a real
Terms/Privacy page must be readable before account creation). Both
carry a prominent, un-missable "pending legal review" banner
(`LegalPageScaffold`).

**Content approach, stated plainly**: the Privacy page describes
Forge's actual current technical data handling as accurately as this
codebase's own audit trail supports (what's stored, where, the mock-only
AI Coach, the honest account-deletion placeholder, no third-party
analytics/ads) — this is factual engineering documentation, not
invented legal text (no claims about jurisdiction, specific-law user
rights, or binding retention commitments). The Terms page is
deliberately much shorter — a status statement plus a checklist of
sections still needing real legal authorship, since actual Terms make
commitments (liability, dispute resolution, governing law) this
codebase has no authority to invent.

## Human legal-review blockers

Tracked explicitly, not hidden inside "PASS":

- Full legal review and approval of both pages' final content.
- A decision on age/eligibility requirements, if any.
- Liability limitation, dispute resolution, and governing-law language
  for Terms of Service.
- Confirmation of what user-rights language (if any) the Privacy Policy
  needs once a target jurisdiction/market is decided.
- Account-deletion disclosure needs to be revisited once real deletion
  is actually implemented (see Item 18's account-deletion-readiness
  findings) — the current page correctly describes it as not yet
  available.

**Until these are resolved, these pages remain drafts — this checklist
does not claim they're store-submission-ready.**

## Accessibility findings

Targeted fixes to the two screens Item 18 flagged as having zero
accessibility code:

- **`ActiveMissionPage`**: the mission title/category header is now a
  semantic heading announcing "Category mission: Title" (previously
  silent); "Progress" and "History" section headers are now marked as
  semantic headers for screen-reader section navigation. The sync/
  authority status badge already had its own internal semantics
  (unchanged, unaffected).
- **`ProgressionPage`** (the Progress tab's real content): the circular
  level-progress ring now announces "Level N, X percent to next level"
  (previously only the bare level number digit was exposed to a screen
  reader, with no context); "Title" and "Category growth" section
  headers are now marked as semantic headers.
- `CategoryProgressRow`'s bar was reviewed and left as-is — it already
  has an adjacent text label ("N / M completed") giving a screen
  reader real content, so it wasn't a genuine gap.

**Not a full-app accessibility audit** — scope was deliberately limited
to the two screens with a proven, documented zero-coverage gap, per
this item's own "fix actual P1 problems... do not perform an unrelated
visual redesign" instruction. All 4 golden tests covering the
Progression page were re-verified pixel-identical after these changes
(Semantics widgets are invisible) — no visual regression.

## Versioning

`pubspec.yaml`: `1.0.0-rc.1+2` (was `1.0.0+1`). Strategy established
(documented in `pubspec.yaml`'s own comment, since no prior policy
existed): `<base-version>-rc.<n>+<build>` — base version fixed through
the RC series, `-rc.N` increments per release candidate, build number
increments on every build regardless of RC number (Android's
versionCode must strictly increase). Drop `-rc.N` for the actual 1.0.0
release once approved. `SettingsAboutSection`'s displayed version
string kept in sync by hand (no `package_info_plus` dependency exists).

## Package identity

Audited, **not changed** (an established identity change needs its own
explicit review, per this item's instruction):

- **Android**: `applicationId`/`namespace` = `com.forge.app.forge`,
  label "forge" — unchanged.
- **Windows**: `Runner.rc` product/company naming is the bundle id
  reused as a display string (`com.forge.app`/"forge") — not a polished
  brand name, but not renamed here either; a branding decision, not a
  hardening one.
- **Web**: title "forge", `manifest.json` name/short_name "forge" —
  unchanged.

## Release assets

Audited, flagged, **not replaced** (no new brand assets were invented,
per instruction — only approved assets already in the repo would be
used, and none exist beyond what's already there):

- Android launcher icon and splash screen are still Flutter template
  defaults — not customized.
- Web `manifest.json`'s `theme_color`/`background_color` is still the
  default Flutter blue (`#0175C2`).
- Windows has a custom icon (`resources\app_icon.ico`) — the one asset
  that is already Forge-specific, not a template default.

## CI changes

Three new jobs added to `.github/workflows/flutter_ci.yml`, all
build-validation only — no signing, no secrets, no artifact publishing:

- **`android-build`** (ubuntu-latest): `flutter build apk --release`.
  Since `android/key.properties` never exists in CI, this always uses
  the debug-signing fallback — exactly the non-production strategy this
  item's own instructions require. This is the job that would have
  caught Item 18's desugaring regression automatically.
- **`web-build`** (ubuntu-latest): `flutter build web --release`.
- **`windows-build`** (windows-latest): `flutter build windows
  --release` — justified because the existing `golden` job already
  proves `windows-latest` GitHub-hosted runners build/run this project
  reliably (the Developer Mode/symlink gate is specific to this
  session's own local machine, not GitHub's hosted runners, which run
  with different permissions).

No production keystore or password is referenced anywhere in CI.

## Clean-install result

Verified via the existing, unchanged test pattern (a fresh
`FakeSecureKeyValueStore()` per test = clean install: no persisted
session, default AI privacy, default notification preferences) — every
test in the full suite that exercises first-run behavior
(`auth_onboarding_flow_test.dart`, the settings/notifications/AI-coach
bootstrap tests) passed clean this pass alongside the rest of the
regression suite. No dedicated new "clean install" test was needed —
this is already how the vast majority of this codebase's widget/
integration tests are structured.

## Existing-user/upgrade result

Verified via the existing account-switch/account-isolation test suite
(`AiPrivacyPreferenceStore`, `LocalReminderStore`,
`CachedMissionAssignmentStore`, `LocalNotificationScheduler.
cancelAllForSignOut` — all confirmed user-scoped, re-verified in Item
18's security re-audit and unchanged since). No cross-account leakage
found.

## Offline result

Covered by the existing, unchanged offline/reconnect test suite
(notification inbox fetch-failure handling, mission sync retry/
idempotency) — all green this pass, no regression.

## Crash/recovery result

`test/core/error/crash_handler_test.dart` (Item 18, re-verified this
pass): confirms `installCrashHandlers()` wires both `FlutterError.
onError` and `PlatformDispatcher.instance.onError` without dropping the
framework's own presentation, and that a controlled test error routes
through cleanly without throwing or looping. Logs via `debugPrint` only
— no secret/raw-sensitive data path exists in `logCrash()` (it logs
`error.toString()` and the stack trace only, both developer-facing,
never shown to a user in the UI).

## Backup/recovery review

`docs/RECOVERY.md` re-read and updated this pass: migration count
corrected to 28 (was 27, one added in Item 18's own performance-index
migration). No new migration added in Item 19. No destructive restore
operation was performed against any environment, staging included.

## Flutter test result

**978 passed / 2 skipped / 0 failed** (was 970 at Item 18's baseline —
8 new tests: legal page content/banner, legal route reachability
[authenticated + unauthenticated], the About section's new links, and
the two accessibility-semantics tests).

## Golden result

**18/18** — unchanged; re-verified the Progression golden tests
specifically pixel-identical after the accessibility Semantics
additions (Semantics widgets are invisible, confirmed empirically).

## Deno result

**25/25 passed.**

## SQL result

**17/17 scripts passed**, re-run via `supabase/tests/verify_backend.sh`
against a fresh `supabase db reset`.

## DB-reset result

Clean — all 28 migrations applied from zero without error, seed
succeeded.

## Final staging smoke

**Not performed** — blocked by the same missing-credentials gate as all
other staging-dependent verification in this pass. No synthetic staging
users were created or needed cleanup, since no staging connection was
ever established.

## Security findings

No new finding this pass. Re-confirmed (not re-derived from scratch):
config guards (`assertBackendModeConfigIsSafe`/
`assertAuthRepositoryConfigIsSafe`) unchanged and correct; the Android
signing-config addition introduces no secret exposure (verified: no
real keystore or password value anywhere in the diff, `key.properties`
correctly gitignored at both levels).

## Secret scan

Clean — scanned the full branch diff for API keys, JWTs, service-role
values, database/staging passwords, keystore file contents, signing
passwords, access tokens, private keys, synthetic test credentials, and
local absolute machine paths. `android/key.properties.example` contains
only placeholder text (`REPLACE_ME`, an example path) — confirmed no
real value was ever written to it or to `key.properties` (which was
created only as a temporary, deliberately-incomplete test file to
verify the Gradle fail-clearly behavior, then deleted before any commit
— never staged, never present in `git status` at any point).

## Classification

**ITEM 19: PARTIALLY VERIFIED.**

No P0 security issue, full Flutter/SQL/Deno regression green, signing
path safely prepared and explicitly blocked awaiting a user-owned key,
legal/privacy routes exist with human-review blockers explicitly
tracked, targeted accessibility fixes landed, CI gained real
release-build coverage. Not "COMPLETE" because: Android real-device/
Windows/staging verification remain genuinely blocked by this
environment (unchanged from Item 18, honestly re-reported rather than
glossed over), and a newly-appeared, environment-level Application
Control policy prevented a final, fresh confirming release build in
this session's last pass (though the exact current code was already
verified to build successfully once, earlier in this same session).
Not "BLOCKED" either — nothing here is stuck pending a decision within
this item's own control; every remaining gap needs either a credential,
a device, or a human legal/business decision this pass correctly
declined to invent.
