# Release Candidate 2

Roadmap Item 20 ("Production Release & Store Submission Prep"). The
authoritative record of RC2's actual state, in the same honest,
gap-tracked style as [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md) (Item
19) and [docs/RELEASE_READINESS.md](RELEASE_READINESS.md) (Item 18).
**This is not a production deployment or app-store submission.** See
[docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md) for the final
gate this feeds into.

**Base commit**: `feature/production-release-prep`, branched from
`develop @ 2f70febd18c28cb7f15cd9632385cdb8c105274c` (Item 19's merge
baseline).

**Version**: `1.0.0-rc.2+3` (was `1.0.0-rc.1+2` — see `pubspec.yaml`'s
own comment; RC number and build number both incremented this pass,
following the strategy Item 19 established).

## Item 20 release matrix

| Area | Result | Detail |
|---|---|---|
| Android signing | BLOCKED (by design) | Unchanged from RC1 — no production keystore exists, none generated. See "Android signing" below. |
| Android AAB CI coverage | PASS (added) | New `android-aab-build` CI job — see "CI changes." |
| Android release build (APK) | PASS (via CI, pending re-verification) | Locally blocked by the same Application Control policy issue documented since Item 19; CI confirmed this exact build config previously. Needs re-confirmation on this branch's own commit once pushed. |
| Android release build (AAB) | UNVERIFIED locally, PENDING CI | Never previously attempted (no job existed before this pass). |
| Android real-device run | BLOCKED | Unchanged — `flutter devices`/`flutter emulators`/`adb` all confirm none available, re-checked this pass. |
| **Android INTERNET permission** | **FIXED (real P1 found this pass)** | `main/AndroidManifest.xml` never declared `android.permission.INTERNET` — only the `debug`/`profile` overlay manifests did (Flutter's dev-connection boilerplate), which does not apply to `release`. No plugin's own manifest supplies it either (checked `flutter_local_notifications`, `flutter_secure_storage`, `flutter_tts` directly — none declare it; `google_fonts`/`timezone`/`supabase_flutter` are pure-Dart, no manifest at all). A real release build would have been unable to make any network call. See "Android permission audit" below. |
| Android permission audit (full) | DONE | See "Android permission audit" below. |
| Android target/API audit | DONE, flagged for policy verification | `compileSdk`/`targetSdk` = 36, `minSdk` = 24 (Flutter 3.47.1's own bundled defaults — confirmed by reading the Flutter SDK's `FlutterExtension.kt` directly, not guessed). See "Android target/API audit" below for the policy-currency caveat. |
| Package identity | UNCHANGED (frozen) | `com.forge.app.forge` — re-confirmed, not touched. |
| Version/build number | UPDATED | `1.0.0-rc.1+2` → `1.0.0-rc.2+3`. |
| Store assets | AUDITED, still missing | See [docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md) — no new asset invented. |
| Play Store prep checklist | DONE | See [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| Draft store copy | DRAFT — REQUIRES HUMAN APPROVAL | See [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md) "Draft store copy." |
| Screenshot plan | DONE, no screenshots captured | See [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md) "Screenshot plan" — blocked on the same real-device gap. |
| Data Safety engineering inventory | DONE | See [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md) "Data Safety engineering inventory." |
| Account deletion design | DONE (design only, not implemented) | See [docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md). |
| Data retention decisions | DONE (facts/options documented, no policy chosen) | See [docs/DATA_RETENTION_DECISIONS.md](DATA_RETENTION_DECISIONS.md). |
| Legal/privacy finalization gate | AWAITING HUMAN/LEGAL APPROVAL (unchanged) | See [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md) "Human legal-review blockers" — nothing resolved this pass, none fabricated either. |
| AI disclosure audit | DONE | See "AI disclosure audit" below. |
| Notification disclosure audit | DONE | See "Notification disclosure audit" below. |
| Accessibility (fuller pass) | DONE | 13 concrete duplicate-announcement fixes across the app this pass — see "Accessibility findings" below. |
| Windows release prep audit | DONE | See "Windows release prep" below. |
| Web release prep audit | DONE | See "Web release prep" below. |
| Production config contract | DONE | See [docs/PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md). |
| Production Supabase readiness | AUDITED, not created | See "Production Supabase readiness" below — no production project created or modified. |
| Staging credential gate | BLOCKED (unchanged) | No real `SUPABASE_ANON_KEY`/staging credentials available in this environment, same as Items 18/19. |
| Security re-audit | DONE, no new P0 | See "Security re-audit" below. |
| Crash/observability re-check | DONE, unchanged and correct | See "Crash/observability re-check" below. |
| Backup/recovery review | RE-CONFIRMED, unchanged | `docs/RECOVERY.md` re-read; migration count (28) and content still accurate, no update needed this pass. |
| CI release gate review | DONE | See "CI changes" below — 7 jobs total now. |
| Dependency audit | DONE, no upgrade performed | See "Dependency audit" below — same 3 deferred majors as Item 18/19, no new low-risk bump available. |
| Full regression | PASS | See "Full regression results" below. |
| Secret scan | PASS (clean) | See "Secret scan" below. |

## Android signing

Unchanged from [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md)'s "Android
signing" and "Signing config" sections — re-read and re-confirmed this
pass, not re-derived from scratch: `android/app/build.gradle.kts`
still reads `android/key.properties` if present, validates all four
required fields with a clear `check(...)` failure if any is missing,
and falls back to debug-signing only when `key.properties` doesn't
exist at all. `.gitignore` coverage re-confirmed at both the repo root
and `android/` level. **No production keystore was generated by this
pass** — see the "Production key human gate" below for exactly what a
human still needs to do.

## Production key human gate

**STOP — this subsection requires a human with account/business
authority, not an engineering decision.** Restated from RC1 for this
item's own record (the underlying facts are unchanged):

1. Generate a real keystore **outside this repository** (a password
   manager's file storage or a dedicated secrets vault), using:
   ```
   keytool -genkey -v -keystore <path> -keyalg RSA -keysize 2048 -validity 10000 -alias forge-release
   ```
2. Choose a strong store password and key password (can be the same
   value; two independent ones is safer). **Never print, log, or commit
   either.**
3. Copy `android/key.properties.example` to `android/key.properties`
   (gitignored) and fill in the four real values.
4. Back the keystore file up somewhere durable and access-controlled —
   **not solely on one developer's machine**. Losing this key without
   Play App Signing's key-upgrade path pre-configured means the
   existing Play Store listing can never receive another update.
5. Once `android/key.properties` exists with all four fields,
   `android/app/build.gradle.kts` automatically signs release builds
   with it — no other code change is required.

This item does not perform any of the five steps above. It is
documented so it can be executed deliberately, by someone with the
authority to own a production signing key, when the business is ready.

## CI changes

Two new jobs added this pass to
`.github/workflows/flutter_ci.yml`, bringing the workflow to **7 jobs
total**, all still build-validation-only with no secrets or
production credentials:

- **`android-aab-build`** (ubuntu-latest) — `flutter build appbundle
  --release`, debug-signed. Play Store submission requires an `.aab`,
  which a passing `android-build` (APK) job does not by itself prove.
- The existing 5 jobs (`functional`, `golden`, `android-build`,
  `web-build`, `windows-build`) are unchanged.

No production keystore, password, or credential is referenced anywhere
in CI, matching every prior item's own constraint.

## Android release build results

Local `flutter build apk --release` / `flutter build appbundle
--release` were attempted this pass and failed identically to Items
19's documented pattern: `ProcessException: An Application Control
policy has blocked this file` blocking `dartaotruntime.exe`. Not
re-diagnosed in exhaustive detail again (same signature, same
20-second-fast failure already root-caused in Item 19 as a local,
machine-specific environment issue — `flutter analyze`/`flutter
test`/`flutter doctor` all remain unaffected). Per this item's own
instruction ("use CI when local Application Control/Developer Mode
prevents legitimate local verification — do not bypass machine
security controls"), authoritative build confirmation is deferred to
this branch's own CI run once pushed — see
[docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md) for how that
result feeds the final gate.

## Android real-device gate

**BLOCKED**, re-confirmed this pass: `flutter devices` lists only
Windows desktop, Chrome, and Edge; `flutter emulators` reports none
configured; `adb` is not on this machine's PATH. Identical result to
Items 17/18/19 — reported honestly again rather than assumed unchanged
without checking.

## Android permission audit

**Full inventory, this pass:**

| Permission | Source | Why |
|---|---|---|
| `android.permission.INTERNET` | `main/AndroidManifest.xml` — **added this pass** | Required for any Supabase (Auth/REST/Realtime/Edge Function) network call. See the release-matrix finding above — this was a genuine, previously-undiscovered gap: it existed only in the `debug`/`profile` overlay manifests (Flutter's own dev-connection boilerplate), which does not carry into `release`, and no plugin's own manifest supplied it as a merger fallback (checked `flutter_local_notifications`, `flutter_secure_storage`, `flutter_tts` directly by reading their packaged `AndroidManifest.xml` files in the pub cache — none declare it; `google_fonts`/`timezone`/`supabase_flutter` and its transitive Dart-only dependencies have no native Android code, hence no manifest to merge from at all). Fixed by declaring it in `main/AndroidManifest.xml`, which now applies to every build type including `release`. |
| `android.permission.POST_NOTIFICATIONS` | `main/AndroidManifest.xml` (Item 17) | Runtime-requested on Android 13+ only, via `PluginLocalNotificationService.requestPermission()` — declaring it here is required for the request API to exist, it does not itself show a prompt. Unchanged. |
| `android.permission.VIBRATE` | `flutter_local_notifications`'s own packaged manifest | Standard/normal permission for that plugin's own notification behavior (vibration on notification arrival) — not requested at runtime, auto-granted, no user-facing prompt. Not declared by this app directly; confirmed via the plugin's own manifest. |
| `android.permission.INTERNET` (debug/profile only) | `android/app/src/{debug,profile}/AndroidManifest.xml` (Flutter template boilerplate) | Used only by the Flutter tool's own dev connection (hot reload/breakpoints) in non-release builds — unrelated to and unaffected by the `main`-manifest fix above; kept as-is. |

No other permission (camera, location, storage, contacts, exact-alarm,
boot-receiver, biometric, etc.) is declared anywhere in the app or its
native-Android dependencies — confirmed by reading every dependency's
packaged Android manifest directly, not inferred.

## Android target/API audit

`android/app/build.gradle.kts` uses `flutter.compileSdkVersion`/
`flutter.minSdkVersion`/`flutter.targetSdkVersion` — Flutter's own
bundled defaults, no hardcoded override anywhere in this project.
Resolved this pass by reading the installed Flutter SDK's own
`FlutterExtension.kt` directly (`packages/flutter_tools/gradle/src/
main/kotlin/FlutterExtension.kt`, Flutter 3.47.1):

- `compileSdkVersion = 36`
- `targetSdkVersion = 36`
- `minSdkVersion = 24`

**This is read directly from the installed toolchain, not guessed** —
a stronger confirmation than Item 19's circumstantial evidence (which
inferred a likely value from `flutter doctor -v`'s installed-platform
output without confirming the actual Gradle-resolved value).

**Flagged for explicit current-policy verification**: whether API 36
satisfies Google Play's *current* minimum-targetSdk requirement at
actual submission time is Google's own policy, which updates
periodically and cannot be authoritatively confirmed from this
environment — verify against Play Console's own current policy page
before submission rather than trusting this document's snapshot.
Given 36 is the latest stable Android API level as of Flutter 3.47.1's
release, it is very likely compliant, but "very likely" is stated
honestly as an inference, not a verified fact.

## Package identity

**Unchanged, not touched** (an identity change needs its own explicit
review, per this item's instruction) — re-confirmed this pass:
`applicationId`/`namespace` = `com.forge.app.forge` (Android); Windows
`Runner.rc` still uses the bundle id as a display string
(`com.forge.app`/"forge", not a polished brand name — see "Windows
release prep" below); Web title/`manifest.json` name/short_name still
"forge".

## Windows release prep

Audited this pass, nothing changed (no code-signing/Developer-Mode
setting touched):

- **Executable/product naming**: `Runner.rc` — `ProductName`/
  `FileDescription` = "forge", `CompanyName`/copyright = "com.forge.app"
  (the bundle id reused as a display string, not a real company name —
  a branding decision, not a hardening one, unchanged since RC1).
- **Icon**: `windows/runner/resources/app_icon.ico` — already
  Forge-specific, the one platform asset that isn't a template default.
- **Package identity**: no MSIX manifest/identity exists — Forge ships
  as a plain Win32 executable, not an MSIX package. This means no
  Microsoft Store submission is currently possible without adding MSIX
  packaging first (a real, separate scope item, not performed here per
  Section 0's explicit "do not submit to Microsoft Store" rule anyway).
- **Version metadata**: `FileVersion`/`ProductVersion` derive from
  `pubspec.yaml`'s `version:` via Flutter's own Windows build tooling —
  now reflects `1.0.0-rc.2+3` after this pass's version bump; not
  independently hardcoded anywhere.
- **Local storage**: `flutter_secure_storage`'s Windows backend uses
  Windows Credential Manager — no plaintext secret file; unchanged.
- **Notification limitations**: unchanged since Item 17 — no MSIX
  means `LocalNotificationScheduler.cancel()`/`getActiveNotifications()`
  remain limited on Windows (documented, not a regression this pass).
- **Distribution requirements**: without MSIX packaging, a real
  distribution would need either a manual installer/zip distribution or
  MSIX work first; Microsoft Store specifically requires MSIX. Not
  built here — out of scope and explicitly prohibited by Section 0.
- **Local build/run**: still BLOCKED on this specific machine
  (Developer Mode/symlink support disabled, not toggled — see Item
  19's own finding, unchanged) — CI's `windows-build` job remains the
  authoritative build-verification path.

## Web release prep

Audited this pass, nothing changed:

- **`manifest.json`**: name/short_name "forge", description "Forge —
  daily discipline challenge app" (both accurate, not placeholder
  text). `theme_color`/`background_color` still the default Flutter
  blue (`#0175C2`) — cosmetic gap, tracked in
  [docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md), not
  fixed here (no brand color exists to replace it with).
  Maskable/regular icon variants present at 192/512.
  `prefer_related_applications: false` — correct for a standalone PWA
  with no native-app counterpart currently distributed.
- **`index.html`**: `<title>forge</title>`, a real (non-placeholder)
  meta description, correct `apple-mobile-web-app-title`. `base href`
  remains a build-time placeholder (`$FLUTTER_BASE_HREF`), never
  hardcoded — confirmed unchanged.
- **Caching/service-worker behavior**: unchanged from Flutter's own
  default Web build output — no custom service-worker logic exists in
  this codebase to audit beyond the framework default.
- **Auth redirect assumptions**: unchanged — `AuthStateAwareRedirectPolicy`
  and the `protected` route list are platform-agnostic (`go_router`),
  no Web-specific redirect logic exists to diverge from mobile/desktop
  behavior.
- **Legal routes**: `/legal/privacy`/`/legal/terms` (Item 19) are
  reachable on Web exactly as on other platforms — no platform-specific
  gating exists. Still not separately *hosted* anywhere reachable by a
  bare URL outside the app shell itself (see
  [docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md)'s
  Privacy Policy URL row) — that requires an actual Web production
  deployment, explicitly out of scope for this item.
- **No secret leakage**: re-confirmed no `--dart-define` value or
  credential is baked into any committed Web asset — `SUPABASE_URL`/
  `SUPABASE_ANON_KEY` are build-time-only and CI never sets them, so
  every CI-built Web bundle stays in mock mode by construction.

## Production Supabase readiness

**Audit only — no production Supabase project created, modified, or
connected.** What a real production Supabase setup would need,
checked against this codebase's actual requirements:

- All 28 local migrations apply cleanly from zero (re-verified this
  pass, see "Full regression results") — the schema itself is
  reproducible against a fresh project via `supabase db push` or an
  equivalent migration-apply step.
- 9 Edge Functions (`ai-coach`, `finalize-week`, `finalize-season`, and
  6 command functions) would need deployment; `finalize-week`/
  `finalize-season` specifically require `FORGE_CRON_SECRET` and
  `SUPABASE_SERVICE_ROLE_KEY` to be set in that project's function
  environment (see [docs/PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md)) —
  neither exists anywhere in this repository, by design.
- `pg_cron` scheduling for week/season finalization (referenced in the
  migrations, per `docs/ROADMAP.md` Item 13) would need to be
  configured against the real project — a Supabase-dashboard/SQL step
  performed against the live project, not something this repo's
  migrations alone perform automatically on every project.
- Backup tier (daily backups / point-in-time recovery) is a Supabase
  project-settings choice, not something this codebase configures or
  can verify remotely — see [docs/RECOVERY.md](RECOVERY.md)'s existing
  "Confirm and document the actual tier/backup setting" note, unchanged.
- No production Supabase project was created, paused, restored, or
  otherwise touched by this pass — Section 0 of this item's own brief
  prohibits it, and no MCP/API call to any Supabase management surface
  was made.

## Staging credential gate

**BLOCKED, unchanged from Items 18/19.** No real `SUPABASE_ANON_KEY` or
synthetic staging test-user credential exists anywhere in this
repository or environment — re-confirmed absent in `.env.example` and
nowhere else in this session. This blocks only staging-dependent
verification; it does not block anything else in this document, and
nothing here references or prints a real credential value.

## AI disclosure audit

The AI Coach feature is, and remains, entirely mock/deterministic — no
real AI provider (OpenAI, Anthropic, Ollama, etc.) is connected
anywhere in this codebase; `AI_PROVIDER=mock` is the only mode that
does anything (`AI_PROVIDER`/`OLLAMA_BASE_URL` dart-defines are
read nowhere in `lib/`, confirmed unused placeholders — see
[docs/PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md)). `PrivacyPolicyPage`
(Item 19) already discloses this factually ("mock-only AI Coach"). The
draft store copy in [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md)
deliberately omits any AI-related marketing claim for the same reason —
describing a live AI backend the app doesn't have would be a false
claim, not a disclosure gap to fix with more copy. **No change needed
this pass** — the existing disclosure is already accurate.

## Notification disclosure audit

`OsNotificationSettingsTile`/`PluginLocalNotificationService`
(Item 17) request `POST_NOTIFICATIONS` only when the user explicitly
enables notifications in Settings — never on first launch, never
pre-checked, no dark-pattern nagging/re-prompt loop found. Re-read this
pass, confirmed unchanged: the permission request is a direct
consequence of a user-initiated toggle, not an app-initiated interrupt.
**No change needed this pass.**

## Accessibility findings

A fuller pass beyond Item 19's two targeted screens
(`ActiveMissionPage`/`ProgressionPage`). Methodology: rather than
adding `Semantics(` wrappers wherever a screen had zero occurrences
(plain `Text`/button widgets are already accessible by default without
one), the search specifically targeted widgets with a custom,
information-complete `Semantics(label: ...)` that was missing
`excludeSemantics: true` — meaning a screen reader announced the
custom label *and then separately re-announced the same information*
from child `Text`/`Icon` nodes, the exact double-announcement bug class
already fixed for `ForgeProgressRing` in Item 19.

**13 genuine gaps found and fixed** across
`leaderboard_entry_tile.dart`, `dashboard_competition_snapshot.dart`,
`weekly_snapshot_card.dart`, `discipline_overview_card.dart` (`_Stat`),
`dashboard_header.dart` (avatar), `forge_bottom_navigation_bar.dart`,
`mission_transmission_frame.dart`, `legal_page_scaffold.dart`,
`settings_accessibility_section.dart`, `level_badge.dart`,
`achievement_card.dart`, `dashboard_quick_actions.dart`, and
`friend_list_tile.dart`.

`friend_list_tile.dart` required a narrower fix than the rest: it has a
genuine interactive descendant (the "Remove friend" `IconButton`), so
`excludeSemantics: true` on the outer node would have silenced that
button's own semantics entirely — the same mistake already caught once
in `active_mission_page.dart` during Item 19. Instead, only the
decorative avatar/name/level subtree is wrapped in `ExcludeSemantics`,
leaving the button untouched — matching the established, deliberate
pattern already used for `AuthorityStatusBadge`.

Every remaining `Semantics(` call in `lib/` was reviewed (33 files);
the rest were confirmed correct as-is — single-`Text`-child `header:
true` patterns, `liveRegion: true` announcements with no competing
custom label, and cases that already used `ExcludeSemantics`
correctly. `social_page_test.dart`'s one affected assertion was updated
to match the new, correct single-node semantics rather than the
old duplicate child's incidental capitalization. Full regression
(978/978 functional, 18/18 golden) re-confirmed clean after every
change — see "Full regression results."

## Security re-audit

No new P0 or P1 security finding this pass beyond the INTERNET
permission gap already covered above (a functional/networking gap, not
a data-exposure one — its absence would have *broken* live
connectivity, not weakened any access control). Re-confirmed, not
re-derived from scratch:

- `assertBackendModeConfigIsSafe`/`assertAuthRepositoryConfigIsSafe`
  unchanged and correct (release+mock refused, live-without-credentials
  refused) — still unit-tested, still passing.
- RLS/least-privilege grants unchanged since the last privilege-
  affecting migration (`20260826010000_system_wide_least_privilege_
  hardening.sql`); no new migration this pass touches any grant.
- No hardcoded credential, service-role key, or cron secret found
  anywhere in `lib/` — re-confirmed via the secret scan below.
- No new IDOR surface introduced — this pass's only functional (non-
  documentation) code changes are the accessibility `Semantics` fixes
  (presentation-layer only, no data access) and the Android
  `INTERNET` permission addition (a manifest declaration, not a code
  path).

## Crash/observability re-check

`installCrashHandlers()` (Item 18) and its test coverage
(`test/core/error/crash_handler_test.dart`) re-verified passing this
pass, unchanged. `logCrash()` still logs only `error.toString()` and
the stack trace via `debugPrint` — no password, JWT, token, or signing
material has any code path into it. **No paid crash-analytics SaaS
added** (Section 0 doesn't prohibit this specifically, but it was never
in scope for this item either — consistent with Item 18's own
deliberate choice, tracked as a P3 future option). Edge Function
`logOutcome` re-confirmed still hard-coded to its 5 safe fields, no new
Edge Function added this pass to introduce a new logging surface.

## Dependency audit

`flutter pub outdated`, re-run this pass: same three deferred majors as
Item 18/19 — `flutter_riverpod`/`riverpod` (2.6.1→3.4.2),
`flutter_secure_storage` (10.3.1→11.0.0), `go_router` (17.3.0→18.0.0).
No new low-risk same-major bump is available beyond what Item 18
already took (`supabase_flutter` 2.16.0→2.17.2). **No upgrade performed
this pass** — a mass upgrade across three actively-used major
dependencies this close to a release candidate is exactly the
disproportionate-risk change this item's own instructions caution
against.

## Full regression results

Re-run in full this pass, on this branch's own final state (after the
accessibility fixes and the Android manifest fix):

- **Flutter functional**: 978 passed / 2 skipped / 0 failed (same
  count as Item 19's baseline — 1 test's semantics assertion was
  updated, not added/removed, and none of this pass's fixes changed
  test count).
- **Golden**: 18/18 passed, pixel-identical (confirmed empirically —
  every accessibility fix this pass is a `Semantics`-only change,
  invisible to golden tests).
- **`flutter analyze`**: 0 issues.
- **`dart format --set-exit-if-changed`**: clean (0 files would
  change).
- **Deno**: 25/25 passed.
- **SQL**: 16/16 test scripts passed (`002` through `016_notifications.sql`
  — the actual current file count in `supabase/tests/`; recorded here
  as directly observed this pass rather than carried forward from a
  prior session's stated count).
- **DB reset**: all 28 migrations applied cleanly from zero, seed
  succeeded.

## Secret scan

Run via `gitleaks`, scoped to this branch's own commits ahead of
`develop` (`gitleaks detect --log-opts="develop..HEAD"`) — **2 commits
scanned, no leaks found.** A separate full-filesystem scan surfaced
only expected false positives inside gitignored, uncommitted local
build-cache binaries (`.dart_tool/`, `build/` — compiled Dart kernel
snapshots that embed the Dart SDK's own crypto-library test vectors and
`google_fonts`' bundled test-font names, misidentified by entropy-based
detection as private keys/API keys); none of these paths are tracked
by git or would ever be part of a commit or PR diff. `android/
key.properties.example` re-confirmed to contain only placeholder text
(`REPLACE_ME`) — no real value was ever written to it or to
`key.properties` this pass (no `key.properties` file was created at
all this time, unlike Item 19's deliberate incomplete-file test).

## Classification

**ITEM 20: PARTIALLY VERIFIED.**

Not "COMPLETE" — several genuine gaps remain outside this item's own
authority to close: no production signing key exists (by design, needs
a human), Android/Windows real-device-and-run verification remains
unavailable in this environment, staging-dependent verification remains
credential-blocked, legal content remains AWAITING HUMAN/LEGAL
APPROVAL, and several store-submission prerequisites (developer
account, brand assets, hosted Privacy Policy URL, content rating,
account deletion) are explicitly AWAITING HUMAN ACTION or BLOCKED, not
silently treated as done. Not "BLOCKED" either — no P0 issue exists,
every fixable-and-safe finding this pass was fixed (including a
genuine, previously-undiscovered Android networking-permission gap),
the full regression suite is green, and every remaining gap needs
either a credential, a device, a real keystore, a store account, or a
human legal/business decision this pass correctly declined to invent.
See [docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md) for the
explicit gate-by-gate GO/NO-GO/AWAITING-HUMAN-APPROVAL/BLOCKED
breakdown this classification is built from.
