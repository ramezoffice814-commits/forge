# Free Public Beta — Release Plan

Roadmap Item 22 ("Free Public Beta Launch"). How CAN's public beta
would actually be distributed once approved — **nothing in this
document has been executed**. No release has been created, no APK has
been uploaded, no Web build has been deployed. See
[docs/PUBLIC_BETA_SECURITY_GATE.md](PUBLIC_BETA_SECURITY_GATE.md) for
the security posture this plan assumes, and the final "Human Launch
Approval Gate" section of this item's own report for what's actually
being asked for permission to do next.

## Beta environment decision (Section 5)

**Recommendation: reuse `forge-staging`, conditional on a human
confirming its current live state — not a unilateral technical
decision.**

This item does not have live Supabase dashboard/API credentials for
`forge-staging` (the same standing gap reported consistently since
Items 18-21 — no real `SUPABASE_ANON_KEY` or staging test-user
password is available in this environment). That means this pass
**cannot directly verify**:

- Whether `forge-staging`'s Edge Functions are actually deployed (vs.
  only the SQL migrations having been applied there).
- Whether `FORGE_CRON_SECRET`/`SUPABASE_SERVICE_ROLE_KEY` are set in
  that project's function environment.
- Whether `pg_cron` week/season finalization is actually scheduled
  there.
- Whether any test/seed/placeholder data already exists in it from
  prior manual staging work (Items 13/18/19) that a real beta user
  might see mixed in with genuine content (e.g. in a public leaderboard
  view).

**What favors reusing it anyway**: it already exists (zero-cost,
matches this item's own "prefer zero-cost architecture" instruction),
its schema is identical to what's been exhaustively tested locally (28
migrations, 16/16 SQL security tests, re-verified every item since 18),
and creating a *second* project would just relocate the same
verification gap rather than closing it.

**What a human needs to do before this is truly beta-ready**:

1. Log into the Supabase dashboard for `forge-staging` and confirm all
   9 Edge Functions are deployed and current.
2. Confirm `FORGE_CRON_SECRET` and `SUPABASE_SERVICE_ROLE_KEY` are set
   in that project's function secrets (never share these values back
   into this session or this repository).
3. Confirm `pg_cron` scheduling for `finalize-week`/`finalize-season`
   is active.
4. Clear or clearly quarantine any placeholder/test data from prior
   manual staging sessions that shouldn't be visible to a real beta
   user.
5. Confirm the project's own backup tier/setting (see
   [docs/RECOVERY.md](RECOVERY.md) — this document deliberately never
   assumed one is configured).

**If a genuinely separate beta project is preferred instead** (e.g. to
keep staging's own test data fully isolated from real beta users): that
requires creating a new Supabase project, which requires Supabase
account access this pass does not have and will not invent — exact
human action: create the project via the Supabase dashboard, then
apply this repository's 28 migrations via `supabase db push` against
it, deploy the 9 Edge Functions, and set the same two function secrets.

## Web / PWA readiness (Sections 17-18)

Audited, not deployed:

- **CAN branding**: confirmed current — `manifest.json` name/short_name
  "CAN", `theme_color`/`background_color` `#161826`, all icon files
  CAN-branded (Item 21).
- **Manifest fields for installability**: `start_url: "."`,
  `display: "standalone"`, real theme/background colors, maskable icon
  variants present — all satisfied already by Item 21's own icon work.
- **Service worker**: Flutter's Web build tooling generates
  `flutter_service_worker.js` automatically at build time (not present
  in source `web/`, which is normal — it's generated output, not
  something this codebase configures directly). No custom
  service-worker logic exists to audit beyond Flutter's own default.
- **HTTPS**: a hosting-time requirement, not a build-time one — every
  free-hosting candidate below provides it automatically.
- **Routing / deep links / refresh on nested routes**: `go_router`'s
  own URL strategy needs a host that rewrites all paths to `index.html`
  (a standard SPA-hosting requirement) — see "Free hosting options"
  below for which candidates support this without extra configuration.
- **Auth callback origins**: a live Web build talking to real Supabase
  would need its deployed origin added to Supabase Auth's allowed
  redirect URLs — a dashboard configuration step for whoever owns the
  Supabase project, not performed here (explicitly deferred to the
  Human Launch Approval Gate — see Section 21 of this item's own brief:
  "changing Supabase redirect/origin config for a public domain"
  requires that gate).
- **Secrets**: confirmed clean — see
  [docs/PUBLIC_BETA_SECURITY_GATE.md](PUBLIC_BETA_SECURITY_GATE.md)
  "Web security."
- **Unsupported platform features**: OS local notifications are a
  documented no-op on Web (Item 17, unchanged) — the app already
  handles this gracefully, no crash/broken UI.
- **Accessibility**: Item 20's 13 accessibility fixes and all prior
  work apply equally to Web (same widget tree) — no Web-specific gap
  found.

**PWA installability: qualifies**, based on the manifest/icon/service-
worker audit above — no further changes were needed or made this pass.

## Free Web hosting options (Section 19)

| Candidate | SPA routing | Free HTTPS | Custom headers/redirects | Notes |
|---|---|---|---|---|
| **GitHub Pages** | Needs a manual `404.html`-redirects-to-`index.html` trick (no native rewrite config) | Yes | Limited | Simplest to wire from this repo's own GitHub home, but the SPA-routing workaround is a real rough edge for `go_router`'s deep links. |
| **Cloudflare Pages** | Native (`_redirects` file, trivial `/* /index.html 200`) | Yes | Yes | Free tier has no practical bandwidth cap for a beta's expected scale; straightforward `flutter build web` output deploy. |
| **Vercel** | Native | Yes | Yes | Free tier is generous for a beta; well-documented static-site deploy path. |
| **Netlify** | Native (`_redirects` file, same pattern as Cloudflare) | Yes | Yes | Comparable to Cloudflare Pages/Vercel. |

**Recommended: Cloudflare Pages**, as the primary candidate — native
SPA-rewrite support (no workaround needed, unlike GitHub Pages),
generous free tier, simple deploy from a static `flutter build web`
output directory. **Fallback: Netlify or Vercel**, functionally
equivalent for this app's needs. **Not deployed by this pass** — this
is a documented recommendation awaiting the Human Launch Approval Gate.

## Feedback channel (Section 27)

**Recommended: a GitHub Issues template on this repository.** Zero
cost, zero new backend, already where the project's own development
happens, and GitHub accounts are a reasonable bar for beta feedback
(filters out fully anonymous noise while remaining free to anyone).
**Not wired this pass** — creating a public-facing Issues template is
itself a small piece of public surface, appropriately gated behind the
Human Launch Approval Gate rather than added unilaterally. No email
address is invented anywhere in this document, per this item's own
explicit instruction.

## Update strategy (Section 29)

**For this item: manual update via GitHub Releases only.** A user
downloads and installs each new beta APK manually, exactly as described
in [docs/ANDROID_BETA_DEVICE_TEST.md](ANDROID_BETA_DEVICE_TEST.md)'s
"Update test" section — Android's own package manager handles
same-signing-key updates cleanly (no uninstall required). **No
in-app "check for updates" or self-updating APK logic is implemented**
— Section 29 explicitly asks this to be deferred unless "explicitly
justified and secure," and auto-update logic for a side-loaded APK is
real additional attack surface (an update mechanism is exactly the
kind of thing a hostile actor would want to compromise) that has no
justification yet for a first beta round.

## GitHub Release plan (Section 30) — not created

**Release title** (example): `CAN Public Beta — 1.0.0-beta.1`

**Assets** (once a human-signed APK exists, per
[docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md)):

- `CAN-v1.0.0-beta.1+5.apk` — the signed release APK.
- `CAN-v1.0.0-beta.1+5.apk.sha256` — its checksum (see below).
- Release notes (see below), as the release body.

**Release body should include**:

- Version and build number.
- SHA256 checksum, and how to verify it (`certutil -hashfile
  CAN-v1.0.0-beta.1+5.apk SHA256` on Windows, `shasum -a 256
  CAN-v1.0.0-beta.1+5.apk` on macOS/Linux).
- Installation instructions (link to
  [docs/ANDROID_BETA_DEVICE_TEST.md](ANDROID_BETA_DEVICE_TEST.md)'s
  "Install" section).
- The beta disclaimer (see below).
- Known issues (see below).
- Update instructions for future releases.

**Not created by this pass** — this is the exact plan for what a
GitHub Release would contain once approved; no release exists yet.

## Checksums (Section 31)

**Not generated this pass** — no final, human-signed distributable APK
exists yet to check-sum (generating a checksum for a debug or unsigned
build and presenting it as final would be actively misleading). Once
the human-signed APK exists:

```
certutil -hashfile CAN-v1.0.0-beta.1+5.apk SHA256
```

(Windows; `shasum -a 256 <file>` on macOS/Linux) — the resulting hash
gets published alongside the APK in the GitHub Release, so anyone can
verify their download wasn't corrupted or tampered with in transit.

## Release notes (draft, Section 32)

**DRAFT — not published.**

> ## CAN Public Beta 1.0.0-beta.1
>
> This is an early public beta of CAN — a daily-discipline app built
> around structured missions, progression, and fair competition.
>
> **What's in this build:**
> - Daily missions across categories you choose, with a 365-day
>   challenge structure.
> - XP, levels, titles, and achievements.
> - League-based competition with weekly/seasonal standings.
> - Daily Transmission — a narrative check-in framing your daily
>   mission.
> - Notification reminders (opt-in, never automatic).
>
> **Known limitations in this beta:**
> - The AI Coach and Daily Transmission dialogue are currently
>   deterministic/mock content, not a live AI system.
> - Account deletion is not yet self-service — contact us if you need
>   your data removed (see the feedback channel below).
> - Privacy Policy and Terms of Service are drafts pending final legal
>   review — see the in-app Settings → About → Privacy/Terms pages for
>   the current, honest status.
> - This build is Android-only; a Web version is planned but not yet
>   hosted.
>
> **Feedback:** [GitHub Issues link — not yet created].
>
> **Installing:** see [docs/ANDROID_BETA_DEVICE_TEST.md] for step-by-
> step instructions. This APK is distributed outside Google Play —
> you'll need to allow installs from this source.

Every claim above is restricted to what the app actually does today —
no efficacy, health, or AI-capability claims beyond what's real,
matching the same discipline already applied to the Play Store draft
copy in [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md).

## Versioning (Section 33)

`1.0.0-rc.3+4` → `1.0.0-beta.1+5` — see `pubspec.yaml`'s own updated
comment for the full reasoning: the `-rc.` identifier accurately
described the internal hardening track (Items 18-20), but is
misleading for what this build actually is once real external users
install it — `-beta.N` says that honestly. Build number strictly
incremented (4 → 5), preserving Android's `versionCode` monotonicity
requirement regardless of the label change.

## What this document does not do

It does not create a GitHub Release. It does not upload an APK. It
does not deploy a Web build. It does not create a Supabase project or
modify `forge-staging`'s configuration. It does not create a public
feedback channel. All of the above remain gated behind the Human
Launch Approval Gate.
