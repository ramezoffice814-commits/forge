# Play Store Preparation

Roadmap Item 20 ("Production Release & Store Submission Prep"). A
comprehensive checklist for an eventual real Play Store submission —
**this document does not submit anything**. Every item below is either
confirmed done, confirmed missing, or explicitly marked as needing a
human/legal/business decision this codebase has no authority to make.
See [docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md) for the
overall gate this feeds into.

## Submission checklist

| Item | Status | Detail |
|---|---|---|
| Developer account | AWAITING HUMAN ACTION | Requires a real Google Play Console developer account and its one-time registration fee — not something this codebase can create. |
| App signing | BLOCKED (by design) | No production keystore exists; see [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) "Android signing" and "Production key human gate." |
| Release artifact (AAB) | See [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) "Android release build results" | Play Store requires an `.aab`, not an `.apk`. |
| Store listing — app name | DRAFT | "Forge" (already the app's actual name throughout the codebase — `pubspec.yaml`, Android label, Web title). |
| Store listing — short description | DRAFT — REQUIRES HUMAN APPROVAL | See "Draft store copy" below. |
| Store listing — full description | DRAFT — REQUIRES HUMAN APPROVAL | See "Draft store copy" below. |
| App icon / feature graphic / screenshots | MISSING | See [docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md). |
| App category | AWAITING HUMAN ACTION | A business/marketing decision (most likely "Productivity" or "Health & Fitness" given the discipline/habit-tracking subject matter) — not decided here. |
| Content rating questionnaire | AWAITING HUMAN ACTION | Must be completed inside Play Console directly by whoever holds the developer account; this document cannot answer Google's questionnaire on the account owner's behalf. Based on the app's actual content (no user-generated text beyond a display name, no violence/mature content, competitive leaderboards against other users), a low/no-mature-content rating is plausible, but the actual questionnaire answers are a compliance step this document does not perform. |
| Target audience / Families policy | AWAITING HUMAN ACTION | Requires a business decision on target age range; Forge has no age-gating today (see [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md) "Human legal-review blockers" — "a decision on age/eligibility requirements, if any"). |
| Privacy Policy URL | BLOCKED | Needs a live, hosted URL — see [docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md). |
| Data Safety form | ENGINEERING INVENTORY PROVIDED, FORM NOT FILED | See "Data Safety engineering inventory" below — this is the factual input a human still has to transcribe into Play Console's actual form, not the form itself. |
| Ads declaration | READY TO ANSWER: No ads | Confirmed — no ad SDK, ad network, or ad-serving code exists anywhere in `lib/` or `pubspec.yaml`'s dependencies. |
| In-app purchases declaration | READY TO ANSWER: None today | Confirmed — no billing/purchase/IAP package or code exists anywhere in the codebase. |
| Government app / COVID-19 app declarations | READY TO ANSWER: No | Not applicable to Forge's actual subject matter. |
| Target API level compliance | See [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) "Android target/API audit" | Flagged for explicit current-policy verification, not asserted. |
| Pricing & distribution (countries, free/paid) | AWAITING HUMAN ACTION | Business decision, not made here. Forge has no payment/monetization code today, so "free" is the only option the current build actually supports. |
| Testing track (internal/closed/open) | AWAITING HUMAN ACTION | A Play Console workflow decision made at actual submission time. |
| Account deletion requirement | BLOCKED | Play policy requires an in-app deletion path (or documented process) for apps supporting account creation — Forge's is currently a placeholder. See [docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md). |

## Draft store copy

**DRAFT — REQUIRES HUMAN APPROVAL. Not final marketing copy. Every
claim below is restricted to what the current codebase actually does —
no efficacy, health, or productivity-outcome claims are made, since
none of those are substantiated by anything in this app.**

### Short description (draft, ~80 characters)

> Build daily discipline with missions, progression, and fair
> competition.

(79 characters — fits the typical 80-character Play Store limit; verify
against the current limit in Play Console before use.)

### Full description (draft)

> Forge is a daily-discipline app built around a structured
> mission-and-progression system.
>
> **Daily missions.** Complete missions tailored to categories you
> choose. Track your progress day by day across a 365-day challenge
> structure.
>
> **Progression.** Earn XP, level up, and unlock a title as you build a
> consistent track record. Unlock achievements as you hit milestones.
>
> **Fair competition.** Join a league and compete against other users
> in weekly and seasonal standings, with a promotion/demotion system
> designed to keep matchups competitive as your own performance
> changes.
>
> **Daily Transmission.** A daily narrative check-in frames your
> mission for the day.
>
> **Notifications, on your terms.** Opt in to reminders and
> achievement/competition updates — notification permission is only
> ever requested when you choose to enable it, never automatically.
>
> Forge does not use ads and has no in-app purchases.

Notes for whoever finalizes this:

- No claim of clinical, therapeutic, scientific, or "proven" efficacy
  is made anywhere above, deliberately — none is substantiated.
- The "AI Coach" feature exists in the codebase but is described
  honestly elsewhere ([docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md) "Legal/
  privacy content") as a mock/deterministic system, not a real AI
  provider — it is **intentionally omitted from this draft copy**
  rather than described in a way that could imply a live AI backend
  the app doesn't actually have. If a real provider is ever connected,
  this copy should be revisited then, not before.
- "365-day challenge structure" reflects the app's own name and
  internal framing (`365_day_chalange_app`) — confirm this is still
  the intended external framing before publishing, since it's a
  product-identity choice, not just a copy-editing one.

## Screenshot plan

**No screenshots exist yet — none were fabricated for this document.**
Proposed shot list once a real device/emulator is available (see
[docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) "Android
real-device gate" for why none is available in this environment):

1. Dashboard — the main daily-overview screen (discipline progress
   ring, weekly snapshot, quick actions).
2. Active Mission — a mission in progress, showing the progress
   control and category framing.
3. Progression — the level/title/category-growth screen.
4. Competition ("Rank") — the League leaderboard view.
5. Daily Transmission — the character/narrative check-in screen.
6. Settings/Accessibility — optional, demonstrates the app's
   notification and accessibility controls rather than being purely
   promotional.

Each should be captured from a real running build (mock-mode data is
acceptable and expected — nothing here requires live backend data), at
whatever resolution Play Console's current uploader requires (see the
policy-verification note in
[docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md)). None
should be staged with placeholder/lorem-ipsum content if avoidable —
the mock data seeded by `MockSocialSeeder` and friends already produces
realistic-looking sample content for exactly this purpose.

## Data Safety engineering inventory

**This is a factual trace of what the code actually collects and does,
for a human to transcribe into Play Console's Data Safety form — it is
not the form itself, and it is not a legal certification.**

| Data category | Collected? | Detail |
|---|---|---|
| Name | Yes (display name) | User-supplied at sign-up (`profiles.display_name`); used for identity/leaderboard display; not shared with any third party. |
| Email address | Yes | Used for Supabase Auth sign-in/account identity; not shared with any third party; not used for advertising (no ad SDK exists). |
| User IDs | Yes | Supabase Auth `user_id`, used internally for all data-scoping/RLS. |
| Other user-generated content | No | No free-text fields beyond display name; no chat, comments, or file uploads exist anywhere in the app. |
| App activity (in-app actions, mission completions) | Yes | Stored server-side (`mission_events`, `xp_ledger`, etc.) to power progression/competition features — this is core app functionality, not analytics/telemetry. |
| App info and performance (crash logs, diagnostics) | No | `installCrashHandlers()` (Item 18) logs to the local device console only (`debugPrint`) — nothing is transmitted off-device. No crash-reporting SaaS (Crashlytics/Sentry/etc.) is integrated. |
| Device or other identifiers | No | No device-fingerprinting, advertising-ID, or analytics-SDK code exists anywhere in `lib/` or `pubspec.yaml`. |
| Location | No | No location permission is requested; no location code exists. |
| Financial info | No | No payment/billing code exists. |
| Health and fitness | No | No health-data integration (e.g. no HealthKit/Google Fit) exists — "discipline" here refers to habit/mission completion, not any health metric. |
| Photos/videos/audio/files | No | No camera, gallery, or file-picker access exists anywhere in the app. |
| Contacts | No | No contacts-permission or contacts-access code exists. |
| Data shared with third parties | No | No analytics, ads, or third-party SDK exists that would receive user data. Supabase itself (the backend provider) is the sole data processor — whether that needs a separate disclosure depends on Play's exact current policy wording for "processor" vs. "third party," which should be verified at filing time. |
| Data encrypted in transit | Yes | Supabase client connections use HTTPS/TLS by default (`supabase_flutter`'s standard client configuration); nothing in this codebase disables or downgrades that. |
| Data deletion request path | **Not yet available** | See [docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md) — `requestAccountDeletion()` is currently a placeholder. This is a real gap the Data Safety form (and Play policy generally) will need reflected honestly, not glossed over. |

## What this document does not do

It does not file anything in Play Console. It does not create a
developer account, complete a content-rating questionnaire, or answer
Play's Data Safety form on anyone's behalf. It does not finalize the
store copy — every piece of copy above is explicitly a draft awaiting
human approval.
