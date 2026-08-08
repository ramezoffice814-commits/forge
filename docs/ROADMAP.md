# Roadmap

This tracks Forge's build order. Each item was built, tested, and verified
(`dart format`, `flutter analyze`, `flutter test`) before the next one
started. Descriptions below reflect what's actually in the repository —
see [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit together.

## Completed

### 1 — Foundation
Project scaffolding: Flutter project setup, the "Forge" design system
(theme tokens, color ramps, spacing/radius scales), and the shared widget
library (`ForgeButton`, `ForgeCard`, loading/error/empty/offline states)
that every later feature builds on.

### 2 — Navigation
The app shell: a `StatefulShellRoute.indexedStack` hosting the five
bottom-nav tabs (Home, Rank, Progress, Awards, Profile) with state
preserved across tab switches, plus the routing conventions later features
follow (named routes, top-level routes for full-screen experiences that
shouldn't show the bottom nav).

### 3 — Auth
Sign-up, sign-in, forgot-password, and session restore, with a mock
repository as the default and a real Supabase-backed repository behind
`APP_ENV=live`. `AuthStateAwareRedirectPolicy` centralizes every
auth-based redirect decision so no individual screen enforces auth itself.

### 4 — Dashboard
The Home tab's real content: header, discipline/streak overview, weekly
snapshot, league preview card, and the mission card slot that later items
wire up to real mission data.

### 5 — Character System and Daily Transmission Experience
The Watcher character and the full Daily Transmission presentation flow —
reveal, dialogue, mission reveal, accept — built on reusable animation
states, local TTS, synchronized subtitles, and deterministic mock scripts.
Explicitly out of scope at this stage: real AI generation, a real backend,
XP, proof upload, ranking.

### 6 — Discipline Intelligence Engine and Mission Selection Foundation
A deterministic, backend-style rules engine so no mission is ever invented
ad hoc: catalog → eligibility filters → safety policy → difficulty engine
→ recovery policy → personalization scoring → deterministic selection (with
a fallback strategy) → a shared `MissionInstance` that Dashboard and
Transmission both read from, so they can never disagree about today's
mission.

### 7 — Mission Lifecycle, Progress Tracking, and Event Engine
Missions moved from a mutable status flag to a fully event-sourced
lifecycle: 19 typed `MissionEvent`s, a pure `MissionAggregate.rehydrate()`
reducer, an explicit lifecycle transition table, ten reusable progress
controls, a local completion validator, an in-memory event repository, and
`ActiveMissionPage` with a per-mission event timeline. Explicitly out of
scope: a real backend, persistence, XP, proof verification.

### 8 — Progression System, XP Evaluation, Levels, Titles, and Achievement Engine
Mission completions now feed a deterministic, explainable progression
pipeline: XP evaluation with documented caps and diminishing returns, a
generated level ladder, behavior-earned cosmetic titles kept separate from
XP, and an achievement engine with locked/progressing/unlocked states.
Everything is explicitly local-preview-only — see the README's
[Trust Boundaries](../README.md#trust-boundaries).

## Planned Next

The following are named as future direction, not committed scope or
timelines:

- Persistence layer (a real local database, replacing the in-memory event
  repositories so history survives an app restart).
- A real backend for authoritative XP/progression confirmation, matching
  the trust boundary already designed for it.
- Leaderboard / ranking, seasons, and social comparison — deliberately
  deferred from every prior item.
- Real AI-generated character dialogue, replacing the current mock
  scripts.
- Notifications.
- iOS/macOS/Linux platform targets (only Android, Web, and Windows exist
  today).

This list will be revised as priorities change — nothing here is a
promise of order or delivery date.
