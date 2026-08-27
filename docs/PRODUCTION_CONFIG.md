# Production Configuration Contract

Roadmap Item 20 ("Production Release & Store Submission Prep"). This
document lists every configuration variable a production deployment of
Forge would need — **names and classification only, no values**. No
production Supabase project exists yet (see
[docs/RECOVERY.md](RECOVERY.md) and `docs/ROADMAP.md` Item 13 —
`forge-staging` is the only deployed environment), so there is nothing
real to populate this with today; this is the contract a future
production setup must satisfy, written down now so it doesn't get
invented ad hoc under deadline pressure later.

See [lib/core/config/app_config.dart](../lib/core/config/app_config.dart)
for the client-side reader and `.env.example` for the existing
documentation-only reference — this doc supersedes `.env.example` as
the authoritative list (it was missing `FORGE_CRON_SECRET` and
`SUPABASE_SERVICE_ROLE_KEY`, which only the server side reads).

## Classification key

- **Public** — safe to appear in a compiled client binary or build log.
  Not a secret by design.
- **Signing-secret** — Android release-signing material. Never
  committed, never in CI, never printed. See "Android signing" in
  [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md) and the "Android signing"
  section of [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md).
- **Server-secret** — read only by Supabase Edge Functions
  (server-side Deno runtime), never shipped in any client build.
- **CI-secret** — would need to live in GitHub Actions repository/
  environment secrets if a workflow ever needs it (none currently do —
  see "CI changes" below).
- **Staging-only / Production-only** — the same variable name is reused
  across environments; the *value* differs per environment and must
  never be shared between them.

## Client-side (`--dart-define`, read by `AppConfig`)

| Variable | Classification | Purpose |
|---|---|---|
| `APP_ENV` | Public | `mock` (default) or `live`. Controls whether the app talks to Supabase at all. A release build with `APP_ENV` unset stays in mock mode and is refused at startup by `assertBackendModeConfigIsSafe` if `isRelease && isMock` — see `lib/core/backend/backend_mode.dart`. |
| `SUPABASE_TARGET` | Public | `staging` or `production`, required whenever `APP_ENV=live`. No default — an unset or misspelled value is treated as unconfigured, never silently guessed. Prevents a build from ever *accidentally* defaulting to production. |
| `SUPABASE_URL` | Public (staging-only / production-only per build) | The Supabase project's REST endpoint. Public by Supabase's own design — access control is RLS-enforced server-side, not secrecy of this URL. Different value for staging vs. production; never mix them in one build. |
| `SUPABASE_ANON_KEY` | Public (staging-only / production-only per build) | Supabase's anonymous client key. Public by Supabase's own design (see `AppConfig`'s own doc comment) — safe in a compiled client binary. Still project-specific, so staging and production values must never be swapped. |
| `AI_PROVIDER` | Public, currently unused | Placeholder only — nothing in this codebase reads it yet (the AI Coach is fully mock/deterministic). Do not treat as load-bearing until a real provider is wired in. |
| `OLLAMA_BASE_URL` | Public, currently unused | Same as above — placeholder, unread. |

## Server-side (Supabase Edge Function environment, `Deno.env.get`)

| Variable | Classification | Purpose |
|---|---|---|
| `SUPABASE_URL` | Server-secret (in practice: same public URL, but the *service-role-key-bearing* client built from it must never leave the server) | Used by `finalize-week`/`finalize-season` to construct a service-role Supabase client, and by every function's shared auth helper to validate caller JWTs. |
| `SUPABASE_ANON_KEY` | Server-secret (functionally public, see above — listed here because the shared auth helper reads it server-side) | Used by `_shared/auth.ts` to validate the caller's JWT against the project. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-secret — real secret | Grants `finalize-week`/`finalize-season` full database access, bypassing RLS, to perform authoritative weekly/seasonal finalization. **Must never appear in any client build, any `--dart-define`, any log, or any file in this repository.** Lives only in Supabase's own function-environment secret store. |
| `FORGE_CRON_SECRET` | Server-secret — real secret | Shared secret `finalize-week`/`finalize-season` require in the caller's header before doing anything — gates these two functions to Supabase's own `pg_cron` scheduler (or an equivalently trusted caller), not to any authenticated end user. Losing this value means anyone could trigger authoritative week/season finalization on demand. |

## Signing (file-based, not an environment variable)

| Item | Classification | Purpose |
|---|---|---|
| `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) | Signing-secret | Android release-signing configuration, read by `android/app/build.gradle.kts`. Gitignored at both the repo root and `android/` level; `android/key.properties.example` is the only committed artifact, and it carries placeholder text only. See the "Android signing" section of [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) for the full human gate — **not generated by this item**. |

## CI changes

**None required by this contract.** As of this writing, no GitHub
Actions job in `.github/workflows/flutter_ci.yml` references any
secret — every release-build job (`android-build`, `android-aab-build`,
`web-build`, `windows-build`) builds with the debug-signing fallback
because `android/key.properties` never exists in CI, and none of them
set `--dart-define`, so every CI build stays in mock mode. If a future
item adds real signing or a real staging/production smoke test to CI,
the corresponding CI-secret entries (a GitHub Actions repository or
environment secret per signing/staging/production value above) would
need to be added at that time, scoped to the minimum job that actually
needs them — never as a blanket repository-wide secret.

## What this document deliberately does not do

- It does not create, request, or reference any real value for any
  variable above.
- It does not create a production Supabase project (see "Production
  Supabase readiness" in [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md)).
- It does not add any new configuration surface to the app — every
  variable listed here already exists in the current codebase; this is
  an inventory, not a proposal for new config.
