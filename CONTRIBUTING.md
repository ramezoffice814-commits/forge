# Contributing to Forge

Thanks for helping build Forge. This document covers the conventions this
repository expects — please read it before opening a pull request.

## Branching

Branch off `develop` (or `main` if `develop` doesn't exist yet) using one of
these prefixes:

| Prefix | Use for |
|---|---|
| `feature/*` | New functionality |
| `fix/*` | Bug fixes |
| `refactor/*` | Internal restructuring with no behavior change |
| `docs/*` | Documentation only |
| `test/*` | Test-only changes |
| `chore/*` | Tooling, dependencies, repo hygiene |
| `release/*` | Release preparation |

Example: `feature/mission-recovery-mode`, `fix/xp-daily-cap-rounding`.

## Before opening a pull request

Every PR must pass all three of these locally:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

CI runs the same three commands and will fail the build if any of them do.
Please don't open a PR with known-failing formatting, analysis, or tests
and ask for an exception — fix it first, or explain why in the PR
description if there's a genuine reason it can't pass yet.

## Architecture rules

- **Feature-first.** New functionality lives under
  `lib/features/<feature>/{domain,data,presentation}/`, not scattered
  across shared folders.
- **Domain stays Flutter-independent where the existing code already keeps
  it that way.** If you're adding to a domain layer that currently has no
  Flutter import (policies, engines, entities, use cases), keep it that
  way — pure Dart, unit-testable without a widget tree. Don't reach for
  `flutter/material.dart` in a domain file to save an import elsewhere.
- **Don't put business logic in widgets.** Formulas, eligibility rules,
  and state transitions belong in the domain layer behind a policy or use
  case, not inline in a widget's `build()`.
- **Respect existing trust boundaries.** Anything that touches XP,
  achievements, or progression must stay explicitly non-authoritative on
  the client (see the README's Trust Boundaries section) — don't add a
  code path that treats a local computation as a confirmed, competitive
  value.

## Tests

- **Business logic changes require tests.** A new or changed policy, use
  case, or engine rule needs unit coverage; a new lifecycle transition
  needs a test proving both the legal and an illegal path.
- Prefer deterministic fixtures over randomness. Several existing test
  suites use exhaustive deterministic sweeps instead of random fuzzing
  specifically so failures reproduce reliably — follow that pattern for
  new policy/engine tests rather than introducing `Random()`.
- Widget-visible changes should get a widget test; a new full user flow
  spanning multiple features should get an integration test under
  `test/integration/`.
- If you touch a screen covered by a golden test and the visual change is
  intentional, regenerate it with `flutter test --update-goldens` and
  review the diff — don't regenerate goldens to hide an unrelated
  regression.

## No secrets, ever

- Never commit `.env` files, API keys, tokens, service-role keys,
  keystores, or signing credentials — see `.gitignore` for what's already
  excluded and extend it if you introduce a new category of local secret.
- If you need a new configuration value, wire it through
  `lib/core/config/app_config.dart` via `--dart-define` and document it in
  `.env.example`, following the existing pattern — don't hardcode it.
- If you accidentally commit a secret, don't just delete it in a follow-up
  commit — it's still in history. Flag it immediately so it can be
  rotated and the history can be cleaned up properly.

## Security-sensitive changes

Changes touching auth, session storage, the Supabase repository path, the
mission-lifecycle event repository, or the progression trust boundary
require an explicit review pass before merge — call this out in the PR
description so it doesn't get merged on a quick skim. See
[SECURITY.md](SECURITY.md) for how to report a vulnerability separately
from normal PR review.

## Commit style

Prefer clear, conventional-style messages describing *why*, not just
*what*: `fix: correct XP daily-cap rounding for repeated missions` rather
than `update xp_calculation_policy.dart`. Squash noisy work-in-progress
commits before requesting review where practical.
