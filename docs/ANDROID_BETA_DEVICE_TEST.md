# Android Beta Device Test Checklist

Roadmap Item 22 ("Free Public Beta Launch"). No Android device or
emulator has been available in this environment across Items 17-22 —
`flutter devices`/`flutter emulators`/`adb` all consistently report
none. **This checklist exists so a human with a real Android device can
actually perform this verification** — nothing in this document has
been performed or faked by this pass. See "Device verification status"
below for the exact, current AWAITING status.

## Before you start

- You'll need the signed beta APK — see
  [docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md)
  for how it gets built, and
  [docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md) for how it's
  packaged and distributed.
- Have a way to capture screenshots and, ideally, `adb logcat` output
  if something goes wrong (`adb logcat | grep flutter` while the app is
  running, if you have Android platform-tools installed).

## Install

- [ ] Enable "install from unknown sources" for whichever app you'll
      use to open the APK (browser, file manager) — Android's exact
      prompt wording varies by version; if you download the APK
      directly in Chrome, Chrome itself will prompt for this on first
      install.
- [ ] Install the APK.
- [ ] Confirm the **CAN icon** appears correctly on the home screen and
      in the app drawer (not a generic Android icon, not the old Forge
      icon) — check it doesn't look clipped or oddly cropped, which
      would indicate an adaptive-icon safe-zone issue not caught by
      this pass's own (non-visual) asset tests.
- [ ] Launch the app. Confirm the **native splash** is deep navy, not a
      white flash, and shows a static CAN mark briefly before the
      **cinematic opening** animation takes over.
- [ ] Confirm the cinematic opening plays smoothly (no visible jank),
      completes, and transitions cleanly into onboarding (first
      launch).
- [ ] Complete onboarding.
- [ ] Confirm the **"CAN Beta"** disclaimer (Settings → About) is
      present.

## Core flow

- [ ] Create a real account (sign-up) — use a real or disposable email
      you control, since this is a real Supabase Auth account.
- [ ] Confirm you land on the Dashboard after sign-up.
- [ ] Open **Daily Transmission** — confirm the character dialogue
      plays/displays and subtitles are legible.
- [ ] Start a mission from the Dashboard.
- [ ] Complete the mission (whatever its progress type requires).
- [ ] Confirm an **XP**/reward confirmation appears.
- [ ] Open **Progress** — confirm level/title/category growth reflects
      the completed mission.
- [ ] Open **Rank** — confirm your league/standing appears (a fresh
      account should show a starting league).
- [ ] Open **Notifications** — confirm the inbox shows the events from
      the flow above (mission completion, any achievement/level-up).
- [ ] Open **Settings** — confirm AI Coach privacy toggle, notification
      preferences, and accessibility controls all work.
- [ ] Open **Settings → About → Privacy** and **Terms** — confirm both
      pages load and show the "pending legal review" banner clearly.
- [ ] Sign out. Confirm you land back on sign-in.
- [ ] Sign back in with the same account. Confirm your data (level,
      completed mission, XP) is still there.

## Network conditions

- [ ] Use the app normally on Wi-Fi.
- [ ] Switch to mobile data mid-session (if available) — confirm no
      crash, and that in-flight actions either complete or fail
      gracefully (a network error state, not a silent hang).
- [ ] Turn on Airplane Mode while the app is open. Confirm an
      "offline"-style state appears where expected (not a raw
      exception).
- [ ] Turn Airplane Mode back off. Confirm the app recovers/reconnects
      without needing a manual restart.

## Lifecycle

- [ ] Background the app (press Home), then return to it. Confirm it
      resumes exactly where you left off, and the cinematic opening
      does **not** replay (it should only ever play once per cold
      launch — see [docs/CAN_REBRAND_AUDIT.md](CAN_REBRAND_AUDIT.md)
      "Lifecycle").
- [ ] Force-close the app (from Android's recent-apps/app-info screen),
      then reopen it. Confirm it launches cleanly — the cinematic
      opening **should** replay here (this is a genuine cold start).
- [ ] If practical, reboot the device and reopen the app. Confirm your
      session is still restored (or you're cleanly prompted to sign in
      again, never a crash).

## Update test (the actual point of the signing work)

- [ ] Install beta build N.
- [ ] Use it briefly, confirm it works.
- [ ] Install beta build N+1 **over** the existing install (do not
      uninstall first) — Android should offer an "update" flow, not a
      fresh-install flow, and should not require re-granting the
      notification permission or losing your locally-restored session.
- [ ] Confirm the app still opens correctly and your account/data are
      unaffected (they're server-side regardless, but confirm the
      local session survived the update cleanly).

## If something fails

- [ ] Note exactly which step failed and what you observed.
- [ ] Take a screenshot if the failure is visual.
- [ ] If you have `adb` available, capture `adb logcat` output from
      around the time of the failure.
- [ ] Report back with the device model, Android version, and beta
      build number (Settings → About).

## Device verification status

**FIRST REAL ANDROID DEVICE TEST PERFORMED — STARTUP ROUTING FAILED,
NOW FIXED, RETEST REQUIRED.** Build `1.0.0-beta.1+5` (signed workflow
run `33261115870`) was downloaded, checksum-verified, and installed on
a real Android device by the human owner — the first time any build
from this project has run on real Android hardware (every prior local
build attempt was blocked by this development machine's Application
Control policy, and CI's own verification steps only inspect the built
APK's signature/package/version, they never launch it). Result:

- **SIGNED APK INSTALLATION = PASS**
- **SIGNED APK LAUNCH = PASS**
- **STARTUP ROUTING = FAIL**
  - Failure: `Not found` / `Page not found` / `No route for '/splash'.`
  - Root cause (fully traced, not the literal "unregistered route" the
    error text implied — see
    [docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md) for the full
    writeup): `/splash` **was** correctly registered. A synchronous
    exception thrown deep in provider construction — reached only
    through the router's own `redirect` callback —
    (`assertAuthRepositoryConfigIsSafe`/
    `assertBackendModeConfigIsSafe` correctly refusing to let a
    *release* build run against the *mock* backend, not yet knowing an
    intentional public beta was a legitimate exception to that rule)
    was caught by go_router and routed to `errorBuilder`, whose message
    was hardcoded to always claim "No route for '\<uri\>'" regardless of
    the real cause. Fixed on both counts: the guards now accept an
    explicit `CAN_PUBLIC_BETA=true` build flag
    (`AppConfig.isPublicBetaBuild`), and `errorBuilder` now surfaces the
    real underlying error instead of a generic, misleading message.
  - This is a genuine regression finding from real-device testing, not
    a hypothetical — recorded honestly rather than silently patched
    over.

**Build `1.0.0-beta.2+6` contains the fix but has not yet been built,
signed, or tested on a real device — REAL_DEVICE_RETEST_REQUIRED = YES.**
Every checklist item above still needs to be executed fresh against
that build once a new signed APK is dispatched and authorized.
